package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin::Authentication';
use Mojo::Loader qw(load_class);

our $VERSION = '0.411';

my $access;# 
my $pkg = __PACKAGE__;
my $conf ;# set on ->registrer


my $fail_auth = {format=>'txt', text=>"Deny at auth step. Please sign in!!!\n"};
my $fail_auth_cb = sub {shift->render(%$fail_auth);};
my $fail_access_cb = sub {
  my ($c, $route, $args, $u) = @_;
  $c->app->log->debug(sprintf "Deny [%s] for user id=[%s]; args=[%s]; defaults=[%s]",
    $route->pattern->unparsed,
    $u->{id},
    $c->dumper($args) =~ s/\s+//gr,
    $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
  );
  $c->render(format=>'txt', text=>"You don`t have access on this route (url, action) !!!\n");
  
};



sub register {
  my ($self, $app,) = (shift, shift);
  $conf = shift; # global
  $conf->{dbh} ||= $app->dbh;
  die "Plugin must work with arg dbh, see SYNOPSIS" unless $conf->{dbh};
  $conf->{access} ||= {};
  $conf->{access}{namespace} ||= $pkg unless $conf->{access}{module};
  $conf->{access}{module} ||= 'Access';
  $conf->{access}{dbh} = $conf->{dbh};
  $conf->{access}{fail_auth_cb} ||= $fail_auth_cb;
  $conf->{access}{fail_access_cb} ||= $fail_access_cb;
  # class obiect
  $access ||= $self->access_instance($app, $conf->{access});
  
  $conf->{auth}{stash_key} ||= $pkg;
  $conf->{auth}{current_user_fn} ||= 'auth_user';
  $conf->{auth}{load_user} ||= \&load_user;
  $conf->{auth}{validate_user} ||= \&validate_user;
  $conf->{auth}{fail_render} ||= $fail_auth;
  $self->SUPER::register($app, $conf->{auth});
  
  $app->routes->add_condition(access => \&access);
  $access->{'app.routes'} = $app->routes;
  $access->apply_route($app, $_) for @{ $access->db_routes };
  
  if ($conf->{admin}) {
    $conf->{admin}{namespace} ||= $pkg;
    $conf->{admin}{controller} ||= 'Admin';
    $conf->{admin}{dbh} = $conf->{dbh};
    $conf->{admin}{sth} = $access->{sth};
    $conf->{admin}{prefix} ||= lc($conf->{admin}{controller});
    $conf->{admin}{trust} ||= $app->secrets->[0];
    my $admin ||= $self->admin_controller($app, $conf->{admin});
    $access->apply_route($app, $_) for $admin->self_routes;
  }
  
  $app->helper('access_instance', sub {$access});
  
  return $self, $access;

}

sub access_instance {# auth, routes and access methods
  my ($self, $app, $conf) = @_;
  my $class  = _load_mod( $conf->{namespace}, $conf->{module});
  $class->import( qw(load_user validate_user) );
  return (bless $conf, $class)->init_class;
}

sub admin_controller {# web interface :)
  my ($self, $app, $conf) = @_;
  my $class  = _load_mod( $conf->{namespace}, $conf->{controller});
  return (bless $conf, $class)->init_class;
}

sub _load_mod {
  my ($ns, $mod) = @_;
  my $class  = join '::', $ns, $mod;
  require join '/', $ns =~ s/::/\//gr, $mod.'.pm';
  return $class;
}


# 
sub access {# add_condition
  my ($route, $c, $captures, $args) = @_;
  #~ $c->app->log->debug($c->dumper($route));#$route->pattern->defaults
  # 1. по паролю выставить куки
  # 2. по кукам выставить пользователя
  my $meth = $conf->{auth}{current_user_fn};
  my $u = $c->$meth;
  # 3. если не проверять доступ вернуть 1
  return 1 unless $args->{auth};
  # не авторизовался
  $conf->{access}{fail_auth_cb}->($c, )
    and return undef
    unless $u;
  #  получить все группы пользователя
  $access->load_user_roles($u);

  my $id2 = [$u->{id}, map($_->{id}, grep !$_->{disable},@{$u->{roles}})];
  my $id1 = [grep $_, @$args{qw(id route_id action_id controller_id namespace_id)}];
  
  # explicit acces to route
  scalar @$id1
    && $access->access_explicit($id1, $id2)
    && $c->app->log->debug(sprintf "Allow [%s] for roles=[%s] joined id1=%s; args=[%s]; defaults=%s",
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
    && $c->app->log->debug(sprintf "Allow [%s] by role [%s] joined roles=[%s]",
      $route->pattern->unparsed,
      $args->{role},
    )
    && return 1;
  
  # implicit access to non db routes
  my $controller = $args->{controller} || ucfirst(lc($route->pattern->defaults->{controller}));
  my $namespace = $args->{namespace} || $route->pattern->defaults->{namespace};
  if ($controller && !$namespace) {
    (load_class($_.'::'.$controller) or ($namespace = $_) and last) for @{ $access->{'app.routes'}->namespaces };
  }
  $conf->{access}{fail_access_cb}->($c, $route, $args, $u)
    and return undef
    unless $controller && $namespace;# failed load class

  $access->access_namespace($namespace, $id2)
    && $c->app->log->debug(sprintf "Allow [%s] for roles=[%s] by namespace=[%s]; args=[%s]; defaults=[%s]",
      $route->pattern->unparsed,
      $c->dumper($id2) =~ s/\s+//gr,
      $namespace,
      $c->dumper($args) =~ s/\s+//gr,
      $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
    )
    && return 1;
  
  $access->access_controller($namespace, $controller, $id2)
    && $c->app->log->debug(sprintf "Allow [%s] for roles=[%s] by namespace=[%s] and controller=[%s]; args=[%s]; defaults=[%s]",
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
    && $c->app->log->debug(sprintf "Allow [%s] for roles=[%s] by controller=[%s] without namespace on db; args=[%s]; defaults=[%s]",
      $route->pattern->unparsed,
      $c->dumper($id2) =~ s/\s+//gr,
      $controller,
      $c->dumper($args) =~ s/\s+//gr,
      $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
    )
    && return 1;
  
  my $action = $args->{action} || $route->pattern->defaults->{action}
    or $conf->{access}{fail_access_cb}->($c, $route, $args, $u)
    and return undef;
  
  $access->access_action($namespace, $controller, $action, $id2)
    && $c->app->log->debug(sprintf "Allow [%s] for roles=[%s] by namespace=[%s] and controller=[%s] and action=[%s]; args=[%s]; defaults=[%s]",
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
    && $c->app->log->debug(sprintf "Allow [%s] for roles=[%s] by (namespace=[any]) controller=[%s] and action=[%s]; args=[%s]; defaults=[%s]",
      $route->pattern->unparsed,
      $c->dumper($id2) =~ s/\s+//gr,
      $controller, $action,
      $c->dumper($args) =~ s/\s+//gr,
      $c->dumper($route->pattern->defaults) =~ s/\s+//gr,
    )
    && return 1;
  
  $conf->{access}{fail_access_cb}->($c, $route, $args, $u);
  return undef;
}


1;

=pod

=encoding utf8

Доброго всем

=head1 Mojolicious::Plugin::RoutesAuthDBI

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

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
    );


=head2 OPTIONS

=over 4

=item * B<dbh> - handler DBI connection where are tables: controllers, actions, routes, users, roles, refs.

=item * B<auth> - hashref options pass to base plugin L<Mojolicious::Plugin::Authentication>.
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

=item * B<admin> - hashref options for admin controller for actions on SQL tables routes, roles, users. By default the builtin module:

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


=back

=head1 INSTALL

See L<Mojolicious::Plugin::RoutesAuthDBI::Install>.


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

