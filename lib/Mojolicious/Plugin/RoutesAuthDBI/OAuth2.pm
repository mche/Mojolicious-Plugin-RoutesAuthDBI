package Mojolicious::Plugin::RoutesAuthDBI::OAuth2;
use Mojo::Base 'Mojolicious::Controller';
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(json_enc json_dec);
use Hash::Merge qw( merge );

has providers => sub {
  {
    vkontakte => {
      key           => "0.........0",
      secret        => "z.................8",
      authorize_url => "https://oauth.vk.com/authorize",
      authorize_query => {display=>'page', response_type=>'code', v=>'5.52',},#&scope=friends
      token_url     => "https://oauth.vk.com/access_token",
      profile_url => 'https://api.vk.com/method/users.get',#?user_ids=260362925&v=5.52&access_token=...
    },
    google=>{# обязательно redirect_url
      key=>'9................0.apps.googleusercontent.com',
      secret=>'J...............1',
      scope=>'profile',
      profile_url=> 'https://www.googleapis.com/oauth2/v1/userinfo',
    },
    yandex=>{# обязательно redirect_url
      key=>'9.............d',
      secret=>'5................f',
      authorize_url=>"https://oauth.yandex.ru/authorize",
      authorize_query => {force_confirm=>1, response_type=>'code',},# state=>
      token_url => "https://oauth.yandex.ru/token",
      profile_url=> "https://login.yandex.ru/info",
    },
  }
  
};

has profile_urls => sub { {
  vkontakte => sub {
    my ($c, $profile_url, $auth, ) = @_;
    $profile_url
      ->query(sprintf qq{user_ids=%s&access_token=%s}, @$auth{qw(user_id access_token)}, );
      #&v=%s     $c->site->{authorize_query}{v}
  },
  google => sub {
    my ($c, $profile_url, $auth, ) = @_;
    $profile_url
      ->query('alt=json&access_token='.$auth->{access_token});
  },
  yandex => sub {
    my ($c, $profile_url, $auth, ) = @_;
    $profile_url
      ->query('format=json&oauth_token='.$auth->{access_token});
  },
}};

has admin => sub {
  require Mojolicious::Plugin::RoutesAuthDBI::Admin;
  bless {}, 'Mojolicious::Plugin::RoutesAuthDBI::Admin';
};

has row_sites => sub {<<SQL};
select *
from @{[shift->oauth_sites]}
where id =? or name =?;
SQL

has ua => sub {shift->app->ua->connect_timeout(30);};


my ($dbh, $sth, $init_conf);
has [qw(dbh sth site)];

sub init {# from plugin
  my $self = shift;
  my %args = @_;

  $self->dbh($self->{dbh} || $args{dbh});
  $dbh = $self->dbh
    or die "Нет DBI handler";
  $self->sth($self->{sth} || $args{sth});
  $sth = $self->sth
    or die "Нет STH";
  #~ $app = $self->app($self->{app} || $args{app});
  
  
  $init_conf = $self;
  return $self;
  
}

sub new {
  my $c = shift->SUPER::new(@_);
  $c->dbh($dbh ||= $c->app->dbh->{'main'});
  my $site = $c->vars('site');
  $c->site($c->oauth2->providers->{$site} || $dbh->selectrow_hashref($dbh->prepare_cached($c->row_sites), undef, ($site =~ /\D/ ? (undef, $site) : ($site, undef))))
    if $site;
  return $c;
}



sub sign {
  my $c = shift;
  #sort($a->{id} <=> $b->{id}, 
  #~ die $c->dumper();
  #~ $c->stash(sites=>[grep($_->{id}, values %{$c->oauth2->providers})]);# || $dbh->selectall_arrayref("select * from @{[$c->oauth_sites]} order by id", {Slice=>{}},));
}

sub out {# выход
  my $c = shift;
  $c->logout;
  $c->redirect_to('home');
}

sub login {
  my $c = shift;
  my $site = $c->site
    or return;
  $c->delay(
    sub { # шаг авторизации
      my $delay = shift;
      my $args = {
        redirect_uri => $c->url_for('oauth-login', site=>$site->{name})->userinfo(undef)->to_abs,
        $site->{authorize_query} ? (authorize_query => $site->{authorize_query}) : (),
      };
      $c->oauth2->get_token($site->{name} => $args, $delay->begin);
    },
    sub {# ну-ка профиль
      my ($delay, $err, $auth) = @_;
      $err .= json_enc($auth->{error})
        if $auth->{error};
      $c->app->log->debug("Автоизация $site->{name}:", $err, $c->dumper($auth));
      return $c->render("oauth/sign", error => $err.' Нет access_token')
        unless $auth->{access_token};
      my $url = $c->${ \$c->profile_urls->{$site->{name}} }(Mojo::URL->new($site->{profile_url}), $auth)
        #~ or die "Нет ссылки для профиля $site->{name}";
        or return $c->render("oauth/sign", error => "Нет ссылки для профиля $site->{name}");
      $c->ua->get($url, $delay->begin);
      $delay->pass($auth);
    },
    sub {# профиль сайта получен
      my ($delay, $tx, $auth) = @_;
      my ($profile, $err) = $c->oauth2->process_tx($tx);
      $err .= json_enc($profile->{error})
        if $profile->{error};
      $c->app->log->debug("Профиль $site->{name}:", $err, $c->dumper($profile));
      return $c->render("oauth/sign", error => $err)
        if $err;
        
      $profile = $profile->{response}
        if $profile->{response};
      $profile = shift @$profile
        if ref $profile eq 'ARRAY';
      @$profile{keys %$auth} = values %$auth;
      
      my $table = $c->oauth_users;
      my @bind = (json_enc($profile), $site->{id}, $auth->{uid} || $auth->{user_id} || $profile->{uid} || $profile->{id});
      my $u = $dbh->selectrow_hashref(<<SQL, undef, @bind)
update $table
set profile = ?, profile_ts=now()
where site_id =? and user_id=?
returning 1::int as "old", *;
SQL
      || $dbh->selectrow_hashref(<<SQL, undef, @bind);
insert into $table (profile, site_id, user_id) values (?,?,?)
returning 1::int as new, *;
SQL
      $c->app->log->debug("$table: ", $c->dumper($u));
      
      my $current_auth = $c->auth_user;
      #~ $c->app->log->debug("Текущий пользователь: ", $c->dumper($current_auth));
      
      my $профиль = 
      
        $current_auth
        
        || $dbh->selectrow_hashref(<<SQL, undef, ($u->{id}))
select p.*
from vinylhub."профили" p
  join vinylhub.refs r on p.id=r.id1
  -- join $table o on o.id=r.id2

where r.id2=?;
SQL

        || $dbh->selectrow_hashref(<<SQL, undef, ([$profile->{first_name} || $profile->{given_name}, $profile->{last_name} || $profile->{family_name},]));
insert into  vinylhub."профили" (names) values(?)
returning 1::int as new, *;
SQL

      #~ my $r = $dbh->selectrow_hashref(<<SQL, undef, ($профиль->{id}, $u->{id}))
#~ insert into vinylhub.refs (id1, id2) values (?,?)
#~ returning *;
#~ ;
#~ SQL
        #~ if $профиль->{new};
      my $r = $c->admin->ref($профиль->{id}, $u->{id},);
      
      $c->authenticate(undef, undef, $профиль)
        unless $current_auth;


      $c->app->log->debug("Профиль винилхаба:", $c->dumper($профиль));
      #~ return $c->session(token => $c->redirect_to('profile'));
      return $c->redirect_to('oauth-sign');
    },
  );
  $c->app->log->debug("Login delay done");
  
}


1;
