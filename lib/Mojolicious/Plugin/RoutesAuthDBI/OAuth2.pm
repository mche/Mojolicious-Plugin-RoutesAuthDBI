package Mojolicious::Plugin::RoutesAuthDBI::OAuth2;
use Mojo::Base 'Mojolicious::Controller';
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(json_enc json_dec);
use Hash::Merge qw( merge );
use Digest::MD5 qw(md5_hex);

my ($dbh, $sth, $init_conf);
has [qw(app dbh sth sites admin)];

has _providers => sub {# default
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
    mailru => {
      key=>'z..........q',
      secret => '1...............9',
      authorize_url=>"https://connect.mail.ru/oauth/authorize",
      token_url => "https://connect.mail.ru/oauth/token",
      profile_url=> "https://www.appsmail.ru/platform/api"

    }
  }
  
};

has config => sub {
  my $self = shift;
  
  while (my ($name, $val) = each %{$self->{providers}}) {
    my $site = $dbh->selectrow_hashref($sth->sth('update oauth site'), undef, ( json_enc($val), $name,))
      || $dbh->selectrow_hashref($sth->sth('new oauth site'), undef, ($name, json_enc($val)));
    @$val{qw(id)} = @$site{qw(id)};
    $val->{name} = $name;
  }
  merge $self->{providers}, $self->_providers;
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
  mailru => sub {
    my ($c, $profile_url, $auth, ) = @_;
    #~ ?&&&sig=f82efdd230e45e58e4fa327fdf92135d&uids=15410773191172635989
    my $param = {
      method=>'users.getInfo',
      app_id=>$c->config->{mailru}{key},
      session_key=>$auth->{access_token},
      uids=$auth->{x_mailru_vid},
      secure=>1,
    };
    $param->{sig} = md5_hex map "$_=$param->{$_}", sort keys %$param;
    $profile_url
      ->query($param);
  },
}};

has ua => sub {shift->app->ua->connect_timeout(30);};

sub init {# from plugin
  my $self = shift;
  my %args = @_;

  $self->dbh($self->{dbh} || $args{dbh});
  $dbh = $self->dbh
    or die "Нет DBI handler";
  $self->sth($self->{sth} || $args{sth});
  $sth = $self->sth
    or die "Нет STH";
  $self->app($self->{app} || $args{app});
  $self->admin($self->{admin} || $args{admin});
  
  die "Plugin OAuth2 already loaded"
    if $self->app->renderer->helpers->{'oauth2.get_token'};
  
  #~ $self->app->log->debug($self->app->dumper($self->config));
  $self->app->plugin("OAuth2" => $self->config);
  
  $init_conf = $self;
  return $self;
  
}

sub login {
  my $c = shift;
  
  my $redirect = $c->param('redirect') || 'profile';
  
  my $site_name = $c->stash('site');

  my $site = $c->oauth2->providers->{$site_name}
    or die "No such oauth provider [$site_name]" ;
  
  die "OAuth provider [$site_name] does not configured"
    unless $site->{id};
    
  my $fail_auth_cb = $init_conf->{fail_auth_cb};

  $c->delay(
    sub { # шаг авторизации
      my $delay = shift;
      my $args = {
        redirect_uri => $c->url_for('oauth-login', site=>$site_name)->userinfo(undef)->to_abs,
        $site->{authorize_query} ? (authorize_query => $site->{authorize_query}) : (),
      };
      $c->oauth2->get_token($site_name => $args, $delay->begin);
    },
    sub {# ну-ка профиль
      my ($delay, $err, $auth) = @_;
      $err .= json_enc($auth->{error})
        if $auth->{error};
      $c->app->log->debug("Автоизация $site_name:", $err, $c->dumper($auth));
      
      return $c->$fail_auth_cb($err.' Нет access_token')
        unless $auth->{access_token};
      
      my $url = $c->${ \$c->profile_urls->{$site_name} }(Mojo::URL->new($site->{profile_url}), $auth)
        or return $c->$fail_auth_cb("Нет ссылки для профиля $site_name");
      
      $c->ua->get($url, $delay->begin);
      $delay->pass($auth);
    },
    sub {# профиль сайта получен
      my ($delay, $tx, $auth) = @_;
      my ($profile, $err) = $c->oauth2->process_tx($tx);
      $err .= json_enc($profile->{error})
        if $profile->{error};
      $c->app->log->debug("Профиль $site_name:", $err, $c->dumper($profile));
      return $c->$fail_auth_cb($err)
        if $err;
        
      $profile = $profile->{response}
        if $profile->{response};
      
      $profile = shift @$profile
        if ref $profile eq 'ARRAY';
      @$profile{keys %$auth} = values %$auth;
      
      my @bind = (json_enc($profile), $site->{id}, $auth->{uid} || $auth->{user_id} || $profile->{uid} || $profile->{id} );
      my $u = $dbh->selectrow_hashref($sth->sth('update oauth user'), undef, @bind)
      || $dbh->selectrow_hashref($sth->sth('new oauth user'), undef, @bind);

      $c->app->log->debug("Oauth user row: ", $c->dumper($u));
      
      my $current_auth = $c->auth_user;
      #~ $c->app->log->debug("Текущий пользователь: ", $c->dumper($current_auth));
      
      my $профиль = 
      
        $current_auth
        
        || $dbh->selectrow_hashref($sth->sth('profile by oauth user'), undef, ($u->{id}))


        || $dbh->selectrow_hashref($init_conf->admin->sth->sth('new profile'), undef, ([$profile->{first_name} || $profile->{given_name}, $profile->{last_name} || $profile->{family_name},]));

      my $r = $init_conf->admin->ref($профиль->{id}, $u->{id},);
      
      $c->authenticate(undef, undef, $профиль)
        unless $current_auth;


      $c->app->log->debug("Профиль: ", $c->dumper($профиль));
      #~ return $c->session(token => $c->redirect_to('profile'));
      return $c->redirect_to($redirect);
    },
  );
  $c->app->log->debug("Login delay done");
  
}


sub out {# выход
  my $c = shift;
  $c->logout;
  $c->redirect_to($c->param('redirect') || 'home');
}

sub _routes {# from plugin!
  my $self = shift;
  
  return (
  
  {request=>'/login/:site',
    namespace=>$init_conf->{namespace},
    controller=>$init_conf->{controller} || $init_conf->{module},
    action => 'login',
    name => 'oauth-login',
  },
  {request =>'/logout',
    namespace=>$init_conf->{namespace},
    controller=>$init_conf->{controller} || $init_conf->{module},
    action => 'out',
    name => 'logout',
  },
  {request =>'/'.$init_conf->admin->{trust}."/oauth/conf",
    namespace=>$init_conf->{namespace},
    controller=>$init_conf->{controller} || $init_conf->{module},
    action => 'conf',
    name => 'oauth-conf',
  }
  
  );
  
}

sub conf {
  my $c = shift;
    $c->render(format=>'txt', text=>
     "PROVIDERS\n---\n"
    . $c->dumper(($c->oauth2->providers))
  );
}

1;

=pod

=encoding utf8

=head1 Mojolicious::Plugin::RoutesAuthDBI::OAuth2

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::OAuth - is a Mojolicious::Controller for oauth2 logins to project. Its has two route: for login and logout.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    $app->plugin('RoutesAuthDBI', 
        ...
        oauth => {< options below >},
        ...
    );


=over 4

=item * B<namespace> - default 'Mojolicious::Plugin::RoutesAuthDBI',

=item * B<controller> - module controller name, default 'OAuth2',


=item * B<providers> - hashref. required.

  providers => {google=>{key=> ..., secret=>..., }, ...},


=item * B<pos> - hashref

SQL-dictionary for DBI statements. See L<Mojolicious::Plugin::RoutesAuthDBI::POS::OAuth2>.

=back

=head2 Defaults

  oauth = > {
    namespace => 'Mojolicious::Plugin::RoutesAuthDBI',
    module => 'OAuth2',
    pos => {
      namespace => 'Mojolicious::Plugin::RoutesAuthDBI',
      module => 'POS::OAuth2',
    },
  },
  
  oauth => undef, # disable oauth
  

=head1 METHODS NEEDS IN PLUGIN

=over 4

=item * B<_routes()> - this oauth controller routes. Return array of hashrefs routes records for apply route on app.

=back

=head1 SEE ALSO

L<Mojolicious::Plugin::RoutesAuthDBI>

L<Mojolicious::Plugin::RoutesAuthDBI::Admin>

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche [on] cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/issues>. Pull requests also welcome.

=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

