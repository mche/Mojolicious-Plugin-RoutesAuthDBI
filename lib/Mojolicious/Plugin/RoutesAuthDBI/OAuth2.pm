package Mojolicious::Plugin::RoutesAuthDBI::OAuth2;
use Mojo::Base 'Mojolicious::Controller';
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(json_enc load_class);
use Hash::Merge qw( merge );
use Digest::MD5 qw(md5_hex);

my ($Init);
has [qw(plugin controller namespace)];

# state here for init and many news
has model => sub { shift->_model};
sub _model { state $model = load_class('Mojolicious::Plugin::RoutesAuthDBI::Model::OAuth')->new }

has _providers => sub {# default
  {
    vkontakte => {
      authorize_url => "https://oauth.vk.com/authorize",
      authorize_query => {display=>'page', response_type=>'code', v=>'5.52',},#&scope=friends
      token_url     => "https://oauth.vk.com/access_token",
      profile_url => 'https://api.vk.com/method/users.get',#?user_ids=260362925&v=5.52&access_token=...
      profile_query => sub {
        my ($c, $auth, ) = @_;
        {
          access_token=>$auth->{access_token},
          fields=>'photo_100',
        };
      },
    },
    google=>{# обязательно redirect_url
      scope=>'profile',
      profile_url=> 'https://www.googleapis.com/oauth2/v1/userinfo',
      profile_query => sub {
        my ($c, $auth, ) = @_;
        {
          alt => 'json',
          access_token => $auth->{access_token},
        };
      },
    },
    yandex=>{# обязательно redirect_url
      authorize_url=>"https://oauth.yandex.ru/authorize",
      authorize_query => {force_confirm=>1, response_type=>'code',},# state=>
      token_url => "https://oauth.yandex.ru/token",
      profile_url=> "https://login.yandex.ru/info",
      profile_query => sub {
        my ($c, $auth, ) = @_;
        {
          format => 'json',
          oauth_token=> $auth->{access_token},
        };
      },
    },
    mailru => {
      authorize_url=>"https://connect.mail.ru/oauth/authorize?response_type=code",
      token_url => "https://connect.mail.ru/oauth/token",
      profile_url=> "https://www.appsmail.ru/platform/api",
      profile_query => sub {
        my ($c, $auth, ) = @_;
        my $param = {
          method=>'users.getInfo',
          app_id=>$Init->config->{mailru}{key},
          session_key=>$auth->{access_token},
          #~ uids=>$auth->{x_mailru_vid},
          secure=>1,
        };
        $param->{sig} = md5_hex map("$_=$param->{$_}", sort keys %$param), $Init->config->{mailru}{secret};
        $param;
      },

    }
  }
  
};

has config => sub {# только $Init ! имя providers уже занято
  my $self = shift;
  
  while (my ($name, $val) = each %{$self->{providers}}) {
    my $site = $self->model->site( json_enc($val), $name,);
    @$val{qw(id)} = @$site{qw(id)};
    $val->{name} = $name;
  }
  merge $self->{providers}, $self->_providers;
};

has curr_profile => sub { shift->${ \$Init->plugin->merge_conf->{auth}{current_user_fn} };};

has ua => sub {shift->app->ua->connect_timeout(30);};

sub init {# from plugin
  state $self = shift->SUPER::new(@_);
  
  die "Plugin OAuth2 already loaded"
    if $self->app->renderer->helpers->{'oauth2.get_token'};
  
  #~ $self->app->log->debug($self->app->dumper($self->config));
  $self->app->plugin("OAuth2::Che" => $self->config);
  
  $Init = $self;
  return $self;
  
}

sub login {
  my $c = shift;
  
  $c->session(oauth_init => {
    redirect => $c->param('redirect') || ($c->req->headers->referrer && Mojo::URL->new($c->req->headers->referrer)->path) || 'profile',
    #~ $c->param('fail_render') ? (fail_render => $c->param('fail_render')) : (),
  })
    unless $c->session('oauth_init');
  
  my $site_name = $c->stash('site');

  my $site = $c->oauth2->providers->{$site_name}
    or die "No such oauth provider [$site_name]" ;
  
  if (my @fatal = grep !defined $site->{$_}, qw(id key secret authorize_url token_url profile_url profile_query)) {
    die "OAuth provider [$site_name] does not configured: [@fatal] is not defined";
  }
  
  my $curr_profile = $c->curr_profile;
  
  my $r; $r = $c->model->check_profile($curr_profile->{id}, $site->{id})
    and $c->app->log->warn("Попытка двойной авторизации сайта $site_name", $c->dumper($r), "профиль: ", $c->dumper($curr_profile),)
    and return $c->redirect_to($c->url_for(${ delete $c->session->{oauth_init} }{redirect})->query(err=> "Уже есть авторизация сайта $site_name"))
    if $curr_profile;

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
      
      $c->app->log->error("Автоизация $site_name:", $err, $c->dumper($auth))
        #~ and return $c->$fail_auth_cb()
        and return $c->redirect_to($c->url_for(${ delete $c->session->{oauth_init} }{redirect})->query(err=> $err.' Нет access_token'))
        unless $auth->{access_token};
      
      my $url = Mojo::URL->new($site->{profile_url})->query($c->${ \$site->{profile_query} }($auth));
      
      $c->ua->get($url, $delay->begin);
      $delay->pass($auth);
    },
    sub {# профиль сайта получен
      my ($delay, $tx, $auth) = @_;
      my ($profile, $err) = $c->oauth2->process_tx($tx);
      $err .= json_enc($profile->{error})
        if ref($profile) eq 'HASH' && $profile->{error};
      
      $c->app->log->error("Профиль $site_name:", $err, $tx->req->url, $c->dumper($tx->res), $c->dumper($profile), )
        #~ and return $c->$fail_auth_cb($err)
        and return $c->redirect_to($c->url_for(${ delete $c->session->{oauth_init} }{redirect})->query(err=> $err))
        if $err;
        
      $profile = $profile->{response}
        if ref($profile) eq 'HASH' && $profile->{response};
      $profile = shift @$profile
        if ref $profile eq 'ARRAY';
      @$profile{keys %$auth} = values %$auth;
      
      my @bind = (json_enc($profile), $site->{id}, $auth->{uid} || $auth->{user_id} || $profile->{uid} || $profile->{id} );
      my $u = $c->model->user(@bind);

      #~ $c->app->log->debug("Oauth user row: ", $c->dumper($u));
      
      #~ $c->app->log->error("Автоизация $site_name:")
        #~ and return $c->$fail_auth_cb()
      return $c->redirect_to($c->url_for(${ delete $c->session->{oauth_init} }{redirect})->query(err=>"Вход на сайт через [$site_name] пользователя #$u->{user_id} уже используется. Невозможно привязать дважды."))
        if $u->{old} && $curr_profile;
      
      my $профиль = 
      
        $curr_profile
        
        || $c->model->profile($u->{id})


        || $Init->plugin->model->{Profiles}->new_profile([$profile->{first_name} || $profile->{given_name}, $profile->{last_name} || $profile->{family_name},]);

      my $r = $Init->plugin->model->{Refs}->refer($профиль->{id}, $u->{id},);
      
      $c->authenticate(undef, undef, $профиль)
        unless $curr_profile;


      #~ $c->app->log->debug("Профиль: ", $c->dumper($профиль));
      return $c->redirect_to(${ delete $c->session->{oauth_init} }{redirect});
    },
  );
  
}

sub отсоединить {
  my $c = shift;
  my $site_name = $c->stash('site');

  my $site = $c->oauth2->providers->{$site_name}
    or die "No such oauth provider [$site_name]" ;
  
  my $curr_profile = $c->curr_profile;
  
  my $r = $c->model->detach($site->{id}, $curr_profile->{id},);
  #~ $c->app->log->debug("Убрал авторизацию сайта [$site_name] профиля [$curr_profile->{id}]", $c->dumper($r));
  
  $Init->plugin->model->{Refs}->del($r->{ref_id}, undef, undef);
  
  $c->redirect_to($c->param('redirect') || 'profile');
}


sub out {# выход
  my $c = shift;
  $c->logout;
  $c->redirect_to($c->param('redirect') || '/');
}

sub _routes {# from plugin!
  my $self = shift;
  
  return (
  
  {request=>'/login/:site',
    namespace => $Init->namespace,
    controller => $Init->controller,
    action => 'login',
    name => 'oauth-login',
  },
  {request=>'/detach/:site',
    namespace => $Init->namespace,
    controller=>$Init->controller,
    action => 'отсоединить',
    name => 'oauth-detach',
    auth=>'only',
  },
  {request =>'/logout',
    namespace => $Init->namespace,
    controller => $Init->controller,
    action => 'out',
    name => 'logout',
  },
  {request =>'/'.$Init->plugin->admin->trust."/oauth/conf",
    namespace => $Init->namespace,
    controller => $Init->controller,
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

=head2 OPTIONS

=head3 namespace

Namespace (string). Defaults to 'Mojolicious::Plugin::RoutesAuthDBI'.

=head3 controller

Module controller name. Defaults to 'OAuth2'.


=head3 providers

Hashref for key/value per each need provider. Required.

  providers => {google=>{key=> ..., secret=>..., }, ...},

See L<Mojolicious::Plugin::OAuth2>. But two additional parameters (keys of provider hash) are needs:

=over 4

=item * B<profile_url> abs url string to fetch profile info after success oauth.

  profile_url=> 'https://www.googleapis.com/oauth2/v1/userinfo',

=item * B<profile_query> coderef which prepare additional query params for C<profile_url>

Example for google:

  profile_query => sub {
    my ($c, $auth, ) = @_;
    {
      alt => 'json',
      access_token => $auth->{access_token},
    };
  },

In: $auth hash ref with access_token.

Out: hashref C<profile_url> query params.

=back

=head2 Defaults options for oauth:

  oauth = > {
    namespace => 'Mojolicious::Plugin::RoutesAuthDBI',
    module => 'OAuth2',
  },

disable oauth module
  
  oauth => undef, 
  

=head1 METHODS NEEDS IN PLUGIN

=head2 _routes()

This oauth controller routes. Return array of hashrefs routes records for apply route on app. Plugin internal use.

=head1 Controller routes

=head2 /login/:site

Main route of this controller. Stash B<site> is the name of the hash key of the C<providers> config above. Example html link:

  <a href="<%= $c->url_for('oauth-login', site=> 'google')->query(redirect=>'profile') %>">Login by google</a>

This route has builtin name 'oauth-login'. This route accept param 'redirect' and will use for $c->redirect_to after success oauith and also failed oauth clauses with param 'err'.

=head2 /detach/:site

Remove attached oauth user to profile. Stash B<site> and param 'redirect' as above. Route has builtin name 'oauth-detach'.

=head2 /logout

Clear session and redirect to param 'redirect' || '/'. This route has builtin name 'logout'. 

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

