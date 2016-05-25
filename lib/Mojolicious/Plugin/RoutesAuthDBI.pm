package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin::Authentication';
use Mojo::Loader qw(load_class);
use Mojo::Util qw(hmac_sha1_sum);
use Hash::Merge qw( merge );

our $VERSION = '0.500';

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
    fail_auth_cb => sub {shift->render(format=>'txt', text=>"Deny at auth step. Please sign in!!!\n");},
    fail_access_cb => sub {
      my ($c, $route, $args, $u) = @_;
      $c->app->log->debug(sprintf "Deny [%s] for user id=[%s]; args=[%s]; defaults=[%s]",
        $route->pattern->unparsed,
        $u->{id},
        $c->dumper($args) =~ s/\s+//gr,
        $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
      );
      $c->render(format=>'txt', text=>"You don`t have access on this route (url, action) !!!\n");
    },
    import => [qw(load_user validate_user)],
  },
  admin => {
    namespace => $pkg,
    controller => 'Admin',
    prefix => lc($self->conf->{admin}{controller} || 'admin'),
    trust => hmac_sha1_sum('admin', $self->app->secrets->[0]),
  },
  pos => {namespace => $pkg, module => 'POS::Pg', },
  sth => {namespace => $pkg, module => 'Sth', },
  template => {schema => 'public'},
}};

has merge_conf => sub {#hashref
  my $self = shift;
  merge($self->conf, $self->default);
};

has pos => sub {# object DBIx::POS::Template
  my $self = shift;
  my $pos = $self->merge_conf->{'pos'};
  my $class = $self->_class($pos);
  $class->new;
};

has sth => sub {# object Sth
  my $self = shift;
  my $sth = $self->merge_conf->{'sth'};
  my $class = $self->_class($sth);
  my $template = $self->merge_conf->{template};
  $class->new($self->dbh, $self->pos, %$template);
};

has access => sub {# object
  my $self = shift;
  my $access = $self->merge_conf->{'access'};
  my $class = $self->_class($access);
  $class->import( @{$access->{import}});
  bless $access, $class;
  $access->{sth} = $self->sth;
  $access->{app} = $self->app;
  return $access->init;
};

has admin => sub {
  my $self = shift;
  my $admin = $self->merge_conf->{'admin'};
  $admin->{module} ||= $admin->{controller};
  my $class = $self->_class($admin);
  bless $admin, $class;
  $admin->{sth} = $self->sth;
  
  return $admin->init;
};


sub register {
  my $self = shift;
  $self->app(shift);
  $self->conf(shift); # global
  
  die $self->app->dumper($self->merge_conf);
  
  $self->dbh($self->conf->{dbh} || $self->app->dbh);
  $self->dbh($self->dbh->($self->app))
    if ref($self->dbh) eq 'CODE';
  die "Plugin must work with dbh, see SYNOPSIS" unless $self->dbh;

  my $access = $self->access;
  $self->SUPER::register($self->app, $self->merge_conf->{auth});
  
  $self->app->routes->add_condition(access => sub {$self->access(@_)});
  $access->apply_ns();
  $access->apply_route($_) for @{ $access->db_routes };
  
  if ($self->conf->{admin}) {
    my $admin = $self->admin;
    $access->apply_route($_) for $admin->self_routes;
  }
  
  $self->app->helper('access', sub {$access});
  
  return $self, $access;

}

sub _class {
  my $self = shift;
  my $conf = shift;
  my $class  = join '::', $conf->{namespace}, $conf->{module};
  my $e; $e = load_class($class)# success undef
    and die $e;
  return $class;
}

# 
sub access {# add_condition
  my $self= shift;
  my ($route, $c, $captures, $args) = @_;
  #~ $c->app->log->debug($c->dumper($route));#$route->pattern->defaults
  # 1. по паролю выставить куки
  # 2. по кукам выставить пользователя
  my $conf = $self->merge_conf;
  my $app = $c->app;
  my $access = $self->access;
  
  my $meth = $conf->{auth}{current_user_fn};
  my $u = $c->$meth;
  if (ref $args eq 'CODE') {
    $args->($u, @_)
      or $access->{fail_auth_cb}->($c, )
      and return undef;
    return 0x01;
  }
  # 3. если не проверять доступ вернуть 1
  return 1 unless $args->{auth};
  # не авторизовался
  $access->{fail_auth_cb}->($c, )
    and return undef
    unless $u;
  # допустить если {auth=>'only'}
  return 1 if lc($args->{auth}) eq 'only';
  
  #  получить все группы пользователя
  $access->load_user_roles($u);

  my $id2 = [$u->{id}, map($_->{id}, grep !$_->{disable},@{$u->{roles}})];
  my $id1 = [grep $_, @$args{qw(id route_id action_id controller_id namespace_id)}];
  
  # explicit acces to route
  scalar @$id1
    && $access->access_explicit($id1, $id2)
    && $app->log->debug(sprintf "Allow [%s] for roles=[%s] joined id1=%s; args=[%s]; defaults=%s",
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
    && $app->log->debug(sprintf "Allow [%s] by role [%s] joined roles=[%s]",
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
  $access->{fail_access_cb}->($c, $route, $args, $u)
    and return undef
    unless $controller && $namespace;# failed load class

  $access->access_namespace($namespace, $id2)
    && $app->log->debug(sprintf "Allow [%s] for roles=[%s] by namespace=[%s]; args=[%s]; defaults=[%s]",
      $route->pattern->unparsed,
      $c->dumper($id2) =~ s/\s+//gr,
      $namespace,
      $c->dumper($args) =~ s/\s+//gr,
      $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
    )
    && return 1;
  
  $access->access_controller($namespace, $controller, $id2)
    && $app->log->debug(sprintf "Allow [%s] for roles=[%s] by namespace=[%s] and controller=[%s]; args=[%s]; defaults=[%s]",
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
    && $app->log->debug(sprintf "Allow [%s] for roles=[%s] by controller=[%s] without namespace on db; args=[%s]; defaults=[%s]",
      $route->pattern->unparsed,
      $c->dumper($id2) =~ s/\s+//gr,
      $controller,
      $c->dumper($args) =~ s/\s+//gr,
      $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
    )
    && return 1;
  
  my $action = $args->{action} || $route->pattern->defaults->{action}
    or $access->{fail_access_cb}->($c, $route, $args, $u)
    and return undef;
  
  $access->access_action($namespace, $controller, $action, $id2)
    && $app->log->debug(sprintf "Allow [%s] for roles=[%s] by namespace=[%s] and controller=[%s] and action=[%s]; args=[%s]; defaults=[%s]",
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
    && $app->log->debug(sprintf "Allow [%s] for roles=[%s] by (namespace=[any]) controller=[%s] and action=[%s]; args=[%s]; defaults=[%s]",
      $route->pattern->unparsed,
      $c->dumper($id2) =~ s/\s+//gr,
      $controller, $action,
      $c->dumper($args) =~ s/\s+//gr,
      $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
    )
    && return 1;
  
  $access->{fail_access_cb}->($c, $route, $args, $u);
  return undef;
}


1;

=pod

=encoding utf8

Доброго всем

=head1 Mojolicious::Plugin::RoutesAuthDBI

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 VERSION

0.448

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
    pos => {...},
  );


=head2 PLUGIN OPTIONS

=head3 dbh

Handler DBI connection where are tables: controllers, actions, routes, users, roles, refs.

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

Hashref options for admin controller for actions on SQL tables routes, roles, users. By default the builtin module:

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

=head3 pos

Hashref options for POS-dictionary instance. See L<Mojolicious::Plugin::RoutesAuthDBI::Sth>.

=back

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

=item * Route accessible if user roles assigned to either B<loadable> namespace or controller 'Bar.pm' (which assigned neither namespece on db or assigned to that loadable namespace) or action 'bar' on controller Bar.pm (action record in db table actions):

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

=item * Route accessible if user roles list has defined role (admin):

  $r->route('/bar-role-admin')->to('bar#bar',)->over(access=>{auth=>1, role=> 'admin'})->...;
  
=item * Pass callback to access condition

The callback will get parameters: $user, $route, $c, $captures, $args (this callback ref). Callback must returns true or false for restrict access. Example simple auth access:

  $r->route('/check-auth')->over(access=>sub {my ($user, $route, $c, $captures, $args) = @_; return $user;})->to(cb=>sub {my $c =shift; $c->render(format=>'txt', text=>"Hi @{[$c->auth_user->{login}]}!\n\nYou have access!");});

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

