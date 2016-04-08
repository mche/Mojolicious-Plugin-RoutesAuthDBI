package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin::Authentication';

our $VERSION = '0.202';

my $access;# 
my $pkg = __PACKAGE__;
my $conf ;# set on ->registrer


my $fail_auth = {format=>'txt', text=>"Deny at auth step. Please sign in!!!\n"};
my $fail_auth_cb = sub {shift->render(%$fail_auth);};
my $fail_access_cb = sub {shift->render(format=>'txt', text=>"You don`t have access on this action!!!\n");};



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
  $access->apply_route($app, $_) for @{ $access->table_routes };
  
  if ($conf->{admin}) {
    $conf->{admin}{namespace} ||= $pkg;
    $conf->{admin}{controller} ||= 'Admin';
    $conf->{admin}{dbh} = $conf->{dbh};
    $conf->{admin}{prefix} ||= lc($conf->{admin}{controller});
    $conf->{admin}{trust} ||= $app->secrets->[0];
    my $admin ||= $self->admin_controller($app, $conf->{admin});
    $access->apply_route($app, $_) for $admin->self_routes;
  }
  
  #~ $app->has('access_instance', $access);
  
  return $self, $access;

}

sub access_instance {# auth, routes and access methods
  my ($self, $app, $conf) = @_;
  my $class  = _load_mod( $conf->{namespace}, $conf->{module});
  $class->import( qw(load_user validate_user) );
  return (bless $conf, $class)->init_class;
}

sub admin_controller {# web interface
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
  my ($route, $c, $captures, $r_item) = @_;
  # 1. по паролю выставить куки
  # 2. по кукам выставить пользователя
  my $meth = $conf->{auth}{current_user_fn};
  my $u = $c->$meth;
  # 3. если не проверять доступ вернуть 1
  return 1 unless $r_item->{auth};
  # не авторизовался
  $conf->{access}{fail_auth_cb}->($c, )
    and return undef
    unless $u;
  # 4. получить все группы пользователя
  $u->{roles} ||= $access->load_user_roles($c, $u->{'id'});
  # 5. по ИДам групп и пользователя проверить доступ
  my $id2 = [$u->{id}, map($_->{id}, grep !$_->{disable},@{$u->{roles}})];
  ($r_item->{id} && $access->access_route($c, $r_item->{id}, $id2))
    and $c->app->log->debug("Access on [$r_item->{namespace}::$r_item->{controller}->$r_item->{action}] for user id=[$u->{id}] by request=[$r_item->{request}]")
    and return 1;
  $access->access_controller($c, $r_item, $id2)
    and $c->app->log->debug("Access all actions on $r_item->{namespace}::$r_item->{controller} for user id=$u->{id} by request=[$r_item->{request}]")
    and return 1;
  $conf->{access}{fail_access_cb}->($c, $route, $r_item);
  #~ $c->app->log->debug($c->dumper($r_item));
  return undef;
}


1;

=encoding utf8

Доброго всем

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !


=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI - Generate routes from sql-table, make authentication and make restrict access (authorization) to route with users/roles tables. Plugin makes an auth operations throught the plugin L<Mojolicious::Plugin::Authentication> on which is based.

=head1 SYNOPSIS

    $app->plugin('RoutesAuthDBI',
        dbh => $app->dbh,
        auth => {...},
        access => {...},
        admin => {...},
    );


=head2 OPTIONS

=over 4

=item * B<dbh> - handler DBI connection where are tables: routes, users, roles, refs.

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


You might define your own controller by passing options:

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


=head1 SQL schema (Postgresql)

See L<Mojolicious::Plugin::RoutesAuthDBI::PgSQL>.

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

L<Mojolicious::Plugin::Authentication>, L<Mojolicious::Plugin::Authorization>

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche [on] cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/issues>. Pull requests also welcome.

=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

