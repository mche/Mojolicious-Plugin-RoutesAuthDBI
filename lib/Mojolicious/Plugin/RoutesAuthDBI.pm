package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin::Authentication';
use Mojo::Loader qw(load_class);
use Mojo::Util qw(hmac_sha1_sum);
use Hash::Merge qw( merge );

our $VERSION = '0.600';

my $pkg = __PACKAGE__;

has [qw(app dbh conf)];

has default => sub {
  my $self = shift;
  {
  auth => {
    stash_key => $pkg,
    current_user_fn => 'auth_user',
    load_user => \&load_user,
    validate_user => \&validate_user,
  },
  access => {
    namespace => $pkg,
    module => 'Access',
    fail_auth_cb => sub {
      shift->render(format=>'txt', text=>"Deny access at auth step. Please sign in.\n");
    },
    fail_access_cb => sub {
      shift->render(format=>'txt', text=>"You don`t have access on this route (url, action).\n");
    },
    import => [qw(load_user validate_user)],
    pos => {
      namespace => $pkg,
      module => 'POS::Access',
    },
  },
  admin => {
    namespace => $pkg,
    controller => 'Admin',
    prefix => lc($self->conf->{admin}{controller} || 'admin'),
    trust => hmac_sha1_sum('admin', $self->app->secrets->[0]),
    pos => {
      namespace => $pkg,
      module => 'POS::Admin',
    },
  },
  oauth => {
    namespace => $pkg,
    controller => 'OAuth',
    pos => {
      namespace => $pkg,
      module => 'POS::OAuth',
    },
  },
  #~ pos => {
    #~ namespace => $pkg,
    #~ module => 'POS::Pg',
    #~ template => {schema => 'pv', tables=>{profiles=>'профили'}},
  #~ },
  sth => {namespace => $pkg, module => 'Sth', },
}};

has merge_conf => sub {#hashref
  my $self = shift;
  merge($self->conf, $self->default);
};

#~ has pos => sub {# object DBIx::POS::Template
  #~ my $self = shift;
  #~ my $pos = $self->merge_conf->{'pos'};
  #~ my $class = $self->_class($pos);
  #~ $class->new($pos->{template} ? (template=>$pos->{template}) : ());
#~ };

has sth => sub {# object Sth
  my $self = shift;
  my $sth = $self->merge_conf->{'sth'};
  #~ my $class = 
  $self->_class($sth);
  #~ my $template = $self->merge_conf->{template};
  #~ $class->new($self->dbh, $self->pos,); #%$template
};

has access => sub {# object
  my $self = shift;
  my $access = $self->merge_conf->{'access'};
  my $class = $self->_class($access);
  $class->import( @{$access->{import}});
  bless $access, $class;
  $access->{dbh} = $self->dbh;
  my $pos = $access->{pos};
  $access->{sth} = $self->sth->new(
    $self->dbh,
    $self->_class($pos)->new($pos->{template} ? (template=>$pos->{template}) : ())
  );
  $access->{app} = $self->app;
  return $access->init;
};

has admin => sub {# object
  my $self = shift;
  my $admin = $self->merge_conf->{'admin'};
  $admin->{module} ||= $admin->{controller};
  my $class = $self->_class($admin);
  bless $admin, $class;
  $admin->{dbh} = $self->dbh;
  my $pos = $admin->{pos};
  $admin->{sth} = $self->sth->new(
    $self->dbh,
    $self->_class($pos)->new($pos->{template} ? (template=>$pos->{template}) : ()),
  );
  
  return $admin->init;
};

has oauth => sub {
  my $self = shift;
  my $oauth = $self->merge_conf->{'oauth'};
  my $class = $self->_class($oauth);
  bless $oauth, $class;
  $oauth->{dbh} = $self->dbh;
  my $pos = $oauth->{pos};
  $oauth->{sth} = $self->sth->new(
    $self->dbh,
    $self->_class($pos)->new($pos->{template} ? (template=>$pos->{template}) : ()),
  );
  return $oauth->init;
};


sub register {
  my $self = shift;
  $self->app(shift);
  $self->conf(shift); # global
  
  $self->dbh($self->conf->{dbh} || $self->app->dbh);
  $self->dbh($self->dbh->($self->app))
    if ref($self->dbh) eq 'CODE';
  die "Plugin must work with dbh, see SYNOPSIS" unless $self->dbh;
  
  my $access = $self->access;
  
  $self->SUPER::register($self->app, $self->merge_conf->{auth});
  
  $self->app->routes->add_condition(access => sub {$self->cond_access(@_)});
  $access->apply_ns();
  $access->apply_route($_) for @{ $access->db_routes };
  
  if ($self->conf->{admin}) {
    my $admin = $self->admin;
    $access->apply_route($_) for $admin->self_routes;
  }
  
  if ($self->conf->{oauth}) {
    my $oauth = $self->oauth;
    $access->apply_route($_) for $oauth->self_routes;
  }
  
  $self->app->helper('access', sub {$access});
  
  return $self, $access;

}

sub _class {
  my $self = shift;
  my $conf = shift;
  my $class  = join '::', $conf->{namespace}, $conf->{module}
    if $conf->{namespace};
  $class ||= $conf->{module};
  
  my $e; $e = load_class($class)# success undef
    and die $e;
  return $class;
}

# 
sub cond_access {# add_condition
  my $self= shift;
  my ($route, $c, $captures, $args) = @_;
  my $conf = $self->merge_conf;
  my $app = $c->app;
  my $access = $self->access;
  #~ $app->log->debug($c->dumper($route));#$route->pattern->defaults
  
  my $auth_helper = $conf->{auth}{current_user_fn};
  my $u = $c->$auth_helper;
  $app->log->debug(sprintf(qq[Access allow [%s] for {auth}=false],
    $route->pattern->unparsed,
  ))
    and return 1 # не проверяем доступ
    unless $args->{auth};
  
  my $fail_auth_cb = $access->{fail_auth_cb};
  
  # не авторизовался
  $self->deny_log($route, $args, $u)
    and $c->$fail_auth_cb()
    and return undef
    unless $u;
  
  #  получить все группы
  $access->load_user_roles($u);
  
  # допустить если {auth=>'only'}
  $app->log->debug(sprintf(qq[Access allow [%s] for {auth}='only'],
    $route->pattern->unparsed,
  ))
    and return 1
    if lc($args->{auth}) eq 'only';
  
  if (ref $args eq 'CODE') {
    $args->($u, @_)
      or $self->deny_log($route, $args, $u)
      and $c->$fail_auth_cb()
      and return undef;
    $app->log->debug(sprintf(qq[Access allow [%s] by callback condition],
      $route->pattern->unparsed,
    ));
    return 0x01;
  }

  my $id2 = [$u->{id}, map($_->{id}, grep !$_->{disable},@{$u->{roles}})];
  my $id1 = [grep $_, @$args{qw(id route_id action_id controller_id namespace_id)}];
  
  # explicit acces to route
  scalar @$id1
    && $access->access_explicit($id1, $id2)
    && $app->log->debug(sprintf "Access allow [%s] for roles=[%s] joined id1=%s; args=[%s]; defaults=%s",
      $route->pattern->unparsed,
      $c->dumper($id2) =~ s/\s+//gr,
      $c->dumper($id1) =~ s/\s+//gr,
      $c->dumper($args) =~ s/\s+//gr,
      $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
    )
    && return 1;
  
  # Access to non db route by role
  $args->{role}
    && $access->access_role($args->{role}, $id2)
    && $app->log->debug(sprintf "Access allow [%s] by role [%s]",
      $route->pattern->unparsed,
      $args->{role},
    )
    && return 1;
  
  # implicit access to non db routes
  my $controller = $args->{controller} || ucfirst(lc($route->pattern->defaults->{controller}));
  my $namespace = $args->{namespace} || $route->pattern->defaults->{namespace};
  if ($controller && !$namespace) {
    (load_class($_.'::'.$controller) or ($namespace = $_) and last) for @{ $app->routes->namespaces };
  }
  
  my $fail_access_cb = $access->{fail_access_cb};
  
  $self->deny_log($route, $args, $u)
    and $c->$fail_access_cb()
    and return undef
    unless $controller && $namespace;# failed load class

  $access->access_namespace($namespace, $id2)
    && $app->log->debug(sprintf "Access allow [%s] for roles=[%s] by namespace=[%s]; args=[%s]; defaults=[%s]",
      $route->pattern->unparsed,
      $c->dumper($id2) =~ s/\s+//gr,
      $namespace,
      $c->dumper($args) =~ s/\s+//gr,
      $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
    )
    && return 1;
  
  $access->access_controller($namespace, $controller, $id2)
    && $app->log->debug(sprintf "Access allow [%s] for roles=[%s] by namespace=[%s] and controller=[%s]; args=[%s]; defaults=[%s]",
      $route->pattern->unparsed,
      $c->dumper($id2) =~ s/\s+//gr,
      $namespace, $controller,
      $c->dumper($args) =~ s/\s+//gr,
      $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
    )
    && return 1;
    
  # еще раз контроллер, который тут без namespace и в базе без namespace ------> доступ из любого места
  $args->{namespace} || $route->pattern->defaults->{namespace}
    || $access->access_controller(undef, $controller, $id2)
    && $app->log->debug(sprintf "Access allow [%s] for roles=[%s] by controller=[%s] without namespace on db; args=[%s]; defaults=[%s]",
      $route->pattern->unparsed,
      $c->dumper($id2) =~ s/\s+//gr,
      $controller,
      $c->dumper($args) =~ s/\s+//gr,
      $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
    )
    && return 1;
  
  my $action = $args->{action} || $route->pattern->defaults->{action}
    or $self->deny_log($route, $args, $u)
    and $c->$fail_access_cb()
    and return undef;
  
  $access->access_action($namespace, $controller, $action, $id2)
    && $app->log->debug(sprintf "Access allow [%s] for roles=[%s] by namespace=[%s] and controller=[%s] and action=[%s]; args=[%s]; defaults=[%s]",
      $route->pattern->unparsed,
      $c->dumper($id2) =~ s/\s+//gr,
      $namespace , $controller, $action,
      $c->dumper($args) =~ s/\s+//gr,
      $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
    )
    && return 1;
  
  # еще раз контроллер, который тут без namespace и в базе без namespace ------> доступ из любого места
  $args->{namespace} || $route->pattern->defaults->{namespace}
    && $access->access_action(undef, $controller, $action, $id2)
    && $app->log->debug(sprintf "Access allow [%s] for roles=[%s] by (namespace=[any]) controller=[%s] and action=[%s]; args=[%s]; defaults=[%s]",
      $route->pattern->unparsed,
      $c->dumper($id2) =~ s/\s+//gr,
      $controller, $action,
      $c->dumper($args) =~ s/\s+//gr,
      $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
    )
    && return 1;
    
  $self->deny_log($route, $args, $u);
  $c->$fail_access_cb();
  return undef;
}

sub deny_log {
  my $self = shift;
  my ($route, $args, $u) = @_;
  my $app = $self->app;
  $app->log->debug(sprintf "Access deny [%s] for profile id=[%s]; args=[%s]; defaults=[%s]",
    $route->pattern->unparsed,
    $u ? $u->{id} : 'non auth',
    $app->dumper($args) =~ s/\s+//gr,
    $app->dumper($route->pattern->defaults) =~ s/\s+//gr,
  );
}

1;

=pod

=encoding utf8

Доброго всем

=head1 Mojolicious::Plugin::RoutesAuthDBI

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 VERSION

0.600

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI - from DBI sql-tables does generate routes, make authentication and make restrict access (authorization) to request. Plugin makes an auth operations throught the plugin L<Mojolicious::Plugin::Authentication> on which is based.

=head1 DB DESIGN DIAGRAM

First of all you will see L<SVG|https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>  or L<PNG|http://i.imgur.com/CwqiB4f.png>

=head1 SYNOPSIS

  $app->plugin('RoutesAuthDBI',
    dbh => $app->dbh,
    auth => {...},
    access => {...},
    admin => {...},
    oauth => {...},
    sth => {...},
  );


=head2 PLUGIN OPTIONS

One option C<dbh> is mandatory, all other - optional.

=head3 dbh

Handler DBI connection where are tables: controllers, actions, routes, logins, profiles, roles, refs.

  dbh => $app->dbh,
  # or
  dbh => sub { shift->dbh },

=head3 auth

Hashref options pass to base plugin L<Mojolicious::Plugin::Authentication>.
By default the option:

  current_user_fn => 'auth_user',
    
The options:

  load_user => \&load_user,
  validate_user => \&validate_user,

are imported from package access module. See below.

=item * B<access> - hashref options for special access module. This module has subs and methods for manage auth and access operations, has appling routes from sql-table. By default plugin will load the builtin module:

  access => {
    module => 'Access',
    namespace => 'Mojolicious::Plugin::RoutesAuthDBI',
    ...,
  },


You might define your own module by passing options:

  access => {
    module => 'Foo',
    namespace => 'Bar::Baz', 
    ...,
  },

See L<Mojolicious::Plugin::RoutesAuthDBI::Access> for detail options list.

=head3 admin

Hashref options for admin controller for actions on SQL tables routes, roles, profiles, logins. By default the builtin module:

  admin => {
    controller => 'Access',
    namespace => 'Mojolicious::Plugin::RoutesAuthDBI',
    ...,
  },


You might define your own controller by passing options:

  admin => {
    controller => 'Foo',
    namespace => 'Bar::Baz', 
    ...,
  },

See L<Mojolicious::Plugin::RoutesAuthDBI::Admin> for detail options list.

=head3 oauth

Hashref options for oauth controller. By default the builtin module:

  oauth => {
    module => 'OAuth',
    namespace => 'Mojolicious::Plugin::RoutesAuthDBI',
    ...,
  },


You might define your own controller by passing options:

  oauth => {
    module => 'Foo::Bar::Baz',
    namespace => '',
    ...,
  },

See L<Mojolicious::Plugin::RoutesAuthDBI::OAuth> for detail options list.

=head3 sth

Hashref options for DBI statements hub. See L<Mojolicious::Plugin::RoutesAuthDBI::Sth>.


=head1 INSTALL

See L<Mojolicious::Plugin::RoutesAuthDBI::Install>.

=head1 OVER CONDITIONS

=head2 access

Heart of this plugin! This condition apply for all db routes even if column auth set to 0. It is possible to apply this condition to non db routes also:

=over 4

=item * No access check to route, but authorization by session will ready:

  $r->route('/foo')->...->over(access=>{auth=>0})->...;

=item * Allow if has authentication only:

  $r->route('/foo')->...->over(access=>{auth=>'only'})->...;
  # same as
  # $r->route('/foo')->...->over(authenticated => 1)->...; # see Mojolicious::Plugin::Authentication

=item * Route accessible if profile roles assigned to either B<loadable> namespace or controller 'Bar.pm' (which assigned neither namespece on db or assigned to that loadable namespace) or action 'bar' on controller Bar.pm (action record in db table actions):

  $r->route('/bar-bar-any-namespace')->to('bar#bar',)->over(access=>{auth=>1})->...;

=item * Explicit defined namespace route accessible either namespace 'Bar' or 'Bar::Bar.pm' controller or action 'bar' in controller 'Bar::Bar.pm' (which assigned to namespace 'Bar' in table refs):

  $r->route('/bar-bar-bar')->to('bar#bar', namespace=>'Bar')->over(access=>{auth=>1})->...;

=item * Check access by overriden namespace 'BarX': controller and action also with that namespace in db table refs:

  $r->route('/bar-nsX')->to('bar#bar', namespace=>'Bar')->over(access=>{auth=>1, namespace=>'BarX'})->...;

=item * Check access by overriden namespace 'BarX' and controller 'BarX.pm', action record also with that ns & c in db table refs:

  $r->route('/bar-nsX-cX')->to('bar#bar', namespace=>'Bar')->over(access=>{auth=>1, namespace=>'BarX', controller=>'BarX'})->...;

=item * Full override names access:

  $r->route('/bar-nsX-cX-aX')->to('bar#bar', namespace=>'Bar')->over(access=>{auth=>1, namespace=>'BarX', controller=>'BarX', action=>'barX'})->...;

=item *

  $r->route('/bar-cX-aX')->to('bar#bar',)->over(access=>{auth=>1, controller=>'BarX', action=>'barX'})->...;

=item * Route accessible if profile roles list has defined role (admin):

  $r->route('/bar-role-admin')->to('bar#bar',)->over(access=>{auth=>1, role=> 'admin'})->...;
  
=item * Pass callback to access condition

The callback will get parameters: $profile, $route, $c, $captures, $args (this callback ref). Callback must returns true or false for restrict access. Example simple auth access:

  $r->route('/check-auth')->over(access=>sub {my ($profile, $route, $c, $captures, $args) = @_; return $profile;})->to(cb=>sub {my $c =shift; $c->render(format=>'txt', text=>"Hi @{[$c->auth_user->{names}]}!\n\nYou have access!");});

=back

=head1 HELPERS

=head2 access

Returns access instance obiect. See L<Mojolicious::Plugin::RoutesAuthDBI::Access> methods.

  $c->access->db_routes;
  if ($c->access->access_explicit([1,2,3], [1,2,3])) {
    # yes, accessible
  }

=head1 METHODS and SUBS

Registration() & access() & <internal>.

=head2 Example routing table records

    Request
    HTTP method(s) (optional)
    and the URL (space delim)
                               Contoller    Method          Route Name        Auth
    -------------------------  -----------  --------------  ----------------- -----
    GET /city/new              City         new_form        city_new_form     1
    GET /city/:id              City         show            city_show         1
    GET /city/edit/:id         City         edit_form       city_edit_form    1
    GET /cities                City         index           city_index        1
    POST /city                 City         save            city_save         1
    GET /city/delete/:id       City         delete_form     city_delete_form  1
    DELETE /city/:id           City         delete          city_delete       1
    /                          Home         index           home_index        0
    get post /foo/baz          Foo          baz             foo_baz           1

It table will generate the L<Mojolicious routes|http://mojolicious.org/perldoc/Mojolicious/Guides/Routing>:

    # GET /city/new 
    $r->route('/city/new')->via('get')->over(<access>)->to(controller => 'city', action => 'new_form')->name('city_new_form');

    # GET /city/123 - show item with id 123
    $r->route('/city/:id')->via('get')->over(<access>)->to(controller => 'city', action => 'show')->name('city_show');

    # GET /city/edit/123 - form to edit an item
    $r->route('/city/edit/:id')->via('get')->over(<access>)->to(controller => 'city', action => 'edit_form')->name('city_edit_form');

    # GET /cities - list of all items
    $r->route('/cities')->via('get')->over(<access>)->to(controller => 'city', action => 'index')->name('cities_index');

    # POST /city - create new item or update the item
    $r->route('/city')->via('post')->to(controller => 'city', action => 'save')->name('city_save');
    
    # GET /city/delete/123 - form to confirm delete an item id=123
    $r->route('/city/delete/:id')->via('get')->over(<access>)->to(controller => 'city', action => 'delete_form')->name('city_delete_form');

    # DELETE /city/123 - delete an item id=123
    $r->route('/city/:id')->via('delete')->over(<access>)->to(controller => 'city', action => 'delete')->name('city_delete');
        
    # without HTTP method and no auth restrict
    $r->route('/')->to(controller => 'Home', action => 'index')->name('home_index');
        
    # GET or POST /foo/baz 
    $r->route('/foo/baz')->via('GET', 'post')->over(<access>)->to(controller => 'Foo', action => 'baz')->name('foo_baz');

=head2 Warning

If you changed the routes table then kill -HUP or reload app to regenerate routes. Changing assess not require reloading the service.

=head1 SEE ALSO

L<Mojolicious::Plugin::Authentication>

L<Mojolicious::Plugin::Authorization>

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche[-at-]cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/issues>. Pull requests also welcome.

=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

