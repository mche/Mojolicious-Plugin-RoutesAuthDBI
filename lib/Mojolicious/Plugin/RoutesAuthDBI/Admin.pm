package Mojolicious::Plugin::RoutesAuthDBI::Admin;
use Mojo::Base 'Mojolicious::Controller';
use Mojolicious::Plugin::RoutesAuthDBI::PgSQL;#  sth cache
use Exporter 'import'; 
our @EXPORT_OK = qw(load_user validate_user);

my $dbh;
my $pkg = __PACKAGE__;
my $plugin_conf;
my $sql;#sth hub

=pod
=encoding utf8

=head NAME

Mojolicious::Plugin::RoutesAuthDBI::Admin - is a mixed Mojolicious::Controller. It invoking from plugin module and might also using as standard Mojolicious::Controller.

=head1 SYNOPSIS

From plugin:
    
    $conf->{admin}{namespace} = 'Mojolicious::Plugin::RoutesAuthDBI';
    $conf->{admin}{controller} = 'Admin';
    require ($conf->{admin}{namespace} =~ s/::/\//gr)."/$conf->{admin}{controller}.pm";
    my $module = "$conf->{admin}{namespace}::$conf->{admin}{controller}";
    $module->import( qw(load_user validate_user) );
    my $admin = (bless $conf->{admin}, $module)->init_class;

From Mojolicious routing:

    $r->get('/myadmin')->over(<access>)->to('admin#index', namespace=>'Mojolicious::Plugin::RoutesAuthDBI',);

=head1 OPTIONS for plugin

    $app->plugin('RoutesAuthDBI',  dbh => $app->dbh, auth => {...}, admin => {<options>},);

=over 4

=item * B<namespace> - default 'Mojolicious::Plugin::RoutesAuthDBI',

=item * B<controller> - default 'Admin',

=item * B<admin_routes> - hashref, key I<prefix> => is prefix for admin urls of this module, key I<trust> => is a url subprefix for admin urls of this module

    admin_routes = > {prefix=>'myadmin', trust => 'foooobaaar'},

By default:

    admin_routes = > {prefix=>'admin', trust => $app->secrets->[0]},
    

=item * B<fail_auth_cb> = sub {my $c = shift;...}

This callback invoke when you need auth route but authentication was failure.

=item * B<fail_access_cb> = sub {my ($c, $route, $r_hash) = @_;...}

This callback invoke when you need auth route but access was failure. $route - Mojolicious::Routes::Route object, $r_hash - route hash db item.

=back

=head1 EXPORT SUBS

=over 4

=item * B<load_user($c, $uid)> - fetch user record from table users by COOKIES. Import for Mojolicious::Plugin::Authentication.

=item * B<validate_user($c, $login, $pass, $extradata)> - fetch user record from table users by Mojolicious::Plugin::Authentication.

=back


head1 METHODS NEEDS IN PLUGIN

=over 4

=item * B<init_class()> - make initialization of class vars: $dbh, $sql, $plugin_conf. Return $self;

=item * B<apply_route($self, $app, $r_hash)> - insert to app->routes an hash item $r_hash. Return new Mojolicious route;

=item * B<table_routes()> - fetch records from table routes. Return arrayref of hashrefs records.

=item * B<load_user_roles($self, $c, $uid)> - fetch records roles for auth user. Return hashref record.

=item * B<access_route($self, $c, $id1, $id2)> - make check access to route by $id1 for user roles ids $id2 arrayref. Return false for deny access or true - allow access.

=item * B<access_controller($self, $c, $r, $id2)> - make check access to route by special route record with request=NULL by $r->{namespace} and $r->{controller} for user roles ids $id2 arrayref. Return false for deny access or true - allow access to all actions of controller.

=back

=cut

######################## PLUGIN SPECIFIC! ##########################################

sub init_class {# from plugin! init Class vars
	my $c = shift;
	my $args = {@_};
  $plugin_conf ||= $c;
  if ($c->{admin_routes}) {
    $c->{admin_routes}{prefix} =~ s/^\///;
    $c->{admin_routes}{trust} =~ s/\W/-/g;
  }
	$c->{dbh} ||= $dbh ||=  $args->{dbh};
	$dbh ||= $c->{dbh};
	$c->{sql} ||= $sql ||= $args->{sql} ||= bless [$dbh, {}], $c->{namespace}.'::PgSQL';#sth cache
	$sql ||= $c->{sql};
    
	return $c;
}

sub load_user {# import for Mojolicious::Plugin::Authentication
	my ($c, $uid) = @_;
	my $u = $dbh->selectrow_hashref($sql->sth('user/id'), undef, ($uid));
  $c->app->log->debug("Loading user by id=$uid ". ($u ? 'success' : 'failed'));
  return $u;
}

sub validate_user {# import for Mojolicious::Plugin::Authentication
  my ($c, $login, $pass, $extradata) = @_;
  if (my $u = $dbh->selectrow_hashref($sql->sth('user/login'), undef, ($login))) {
    return $u->{id}
      if $u->{pass} eq $pass  && !$u->{disable};
  }
  return undef;
}

sub apply_route {# meth in Plugin
  my ($self, $app, $r_hash) = @_;
  my $r = $app->routes;
  return if $r_hash->{disable};
  return unless $r_hash->{request};
  my @request = grep /\S/, split /\s+/, $r_hash->{request}
    or return;
  my $nr = $r->route(pop @request);
  $nr->via(@request) if @request;
  
  # STEP AUTH не катит! только один over!
  #~ $nr->over(authenticated=>$r_hash->{auth});
  # STEP ACCESS
  $nr->over(access => $r_hash);
  
  $nr->to(controller=>$r_hash->{controller}, action => $r_hash->{action},  $r_hash->{namespace} ? (namespace => $r_hash->{namespace}) : (),);
  $nr->name($r_hash->{name}) if $r_hash->{name};
  #~ $app->log->debug("$pkg generate the route from data row [@{[$app->dumper($r_hash) =~ s/\n/ /gr]}]");
  return $nr;
}

sub table_routes {
  my ($self, $c, ) = @_;
  $dbh->selectall_arrayref($sql->sth('all routes'), { Slice => {} },);
}

sub load_user_roles {
	my ($self, $c, $uid) = @_;
	$dbh->selectall_arrayref($sql->sth('user roles enbl'), { Slice => {} }, ($uid));
}

sub access_route {
	my ($self, $c, $id1, $id2,) = @_;
	return scalar $dbh->selectrow_array($sql->sth('cnt refs'), undef, ($id1, $id2));
}

sub access_controller {
	my ($self, $c, $r, $id2,) = @_;
	return scalar $dbh->selectrow_array($sql->sth('access controller'), undef, ($r->{controller}, $r->{namespace},  $id2));
}

################################ END PLUGIN #################################



sub index {
  my $c = shift;
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

You are signed as:
@{[$c->dumper( $c->auth_user)]}

@{[map "$_->{request}\t\t$_->{descr}\n", $c->admin_routes]}

TXT
    and return
    if $c->is_user_authenticated;
  
  $c->render(format=>'txt', text=>__PACKAGE__."\n\nYou are not signed!!! To sign in/up go to /sign/<login>/<pass>");
}

sub sign {
  my $c = shift;
  
  $c->authenticate($c->stash('login') || $c->param('login'), $c->stash('pass') || $c->param('pass'))
    and $c->render(format=>'txt', text=>__PACKAGE__ . "\n\nSuccessfull signed! ".$c->dumper( $c->auth_user))
    and return;
    
  
  $c->render(format=>'txt', text=>__PACKAGE__ . "\n\nBad sign!!! Try again");
}

sub signout {
  my $c = shift;
  
  $c->logout;
  
  $c->render(format=>'txt', text=>__PACKAGE__ . "\n\nYou are exited!!!");
  
}

sub new_user {
  my $c = shift;
  
  my ($login, $pass) = ($c->stash('login') || $c->param('login'), $c->stash('pass') ||  $c->param('pass'));
  
  my $r;
  ($r = $dbh->selectrow_hashref($sql->sth('user/login'), undef, ($login)))
    and $c->render(format=>'txt', text=><<TXT)
$pkg

User already exists!

@{[$c->dumper( $r)]}
TXT
    and ($r->{not_new} = '!')
    and return $r;
  
  $r = $dbh->selectrow_hashref($sql->sth('new_user'), undef, ($login, $pass));
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

Success sign up new user!

@{[$c->dumper( $r)]}
TXT
  return $r;
}

sub trust_new_user {
  my $c = shift;
  
  my $u = $c->new_user;
  #~ return if $u->{not_new};
  
  # ROLE
  my $rl = $dbh->selectrow_hashref($sql->sth('role'), undef, (undef, 'admin'));
  $rl ||= $dbh->selectrow_hashref($sql->sth('new_role'), undef, ('admin'));
  
  # REF role->user
  my $ru = $dbh->selectrow_hashref($sql->sth('ref'), undef, ($rl->{id}, $u->{id}));
  $ru ||= $dbh->selectrow_hashref($sql->sth('new_ref'), undef, ($rl->{id}, $u->{id}));
  
  # ROUTE
  my $rt = $dbh->selectrow_hashref($sql->sth('route/controller'), undef, ($plugin_conf->{namespace}, $plugin_conf->{controller}));
  $rt ||= $dbh->selectrow_hashref($sql->sth('new_route'), undef, (undef, 'admin controller', $plugin_conf->{namespace}, $plugin_conf->{controller}, undef, 1, "Access to all $plugin_conf->{namespace}\::$plugin_conf->{controller} actions", undef, undef,));
    
    #REF route->role
  my $rr = $dbh->selectrow_hashref($sql->sth('ref'), undef, ($rt->{id}, $rl->{id}));
  $rr ||= $dbh->selectrow_hashref($sql->sth('new_ref'), undef, ($rt->{id}, $rl->{id}));
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

Success sign up new trust-user!

USER:
@{[$c->dumper( $u)]}

ROLE:
@{[$c->dumper( $rl)]}

ROUTE:
@{[$c->dumper( $rt)]}

TXT
}

sub new_role {
	my $c = shift;
	my $name = $c->stash('name');
	my $r = $dbh->selectrow_hashref($sql->sth('role'), undef, (undef, $name));
	$c->render(format=>'txt', text=><<TXT)
$pkg

Exists role!

@{[$c->dumper( $r)]}

TXT
		and return $c
		if $r;
	$r = $dbh->selectrow_hashref($sql->sth('new_role'), undef, ($name));
	
	$c->render(format=>'txt', text=><<TXT);
$pkg

Success created role!

@{[$c->dumper( $r)]}

TXT
	
}

sub user_roles {
  my $c = shift;
  my $user = $c->stash('user') || $c->param('user');
  my $u =  $dbh->selectrow_hashref($sql->sth('user'), undef, ($user =~ s/\D//gr || undef, $user));
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such user [$user]!

TXT
    and return
    unless $u;
  
  my $r = $dbh->selectall_arrayref($sql->sth('user roles'), { Slice => {} }, ($u->{id}));
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

USER
@{[$c->dumper( $u)]}

ROLES
@{[$c->dumper( $r)]}

TXT
  
}

sub new_role_user {
  my $c = shift;
  
  my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sql->sth('role'), undef, ($role =~ s/\D//gr || undef, $role));
  $c->render(format=>'txt', text=><<TXT)
$pkg

Can't create new role by only digits[$role] in name!

TXT
    and return
    unless $r && $role =~ /\w/;
  $r ||= $dbh->selectrow_hashref($sql->sth('new_role'), undef, ($role)) ;
  
  
  
  my $user = $c->stash('user') || $c->param('user');
  my $u =  $dbh->selectrow_hashref($sql->sth('user'), undef, ($user =~ s/\D//gr || undef, $user));
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such user [$user]!

TXT
    and return
    unless $u;
  
  my $ref = $dbh->selectrow_hashref($sql->sth('ref'), undef, ($r->{id}, $u->{id}));
  $c->render(format=>'txt', text=><<TXT)
$pkg

Allready ref ROLE->USER!

@{[$c->dumper( $ref)]}
TXT
    and return
    if $ref;
  
  $ref = $dbh->selectrow_hashref($sql->sth('new_ref'), undef, ($r->{id}, $u->{id}));
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

Success create ref ROLE->USER!

@{[$c->dumper( $ref)]}
TXT
  
  
}

sub role_users {# все пользователи роли по запросу /myadmin/users/:role
  my $c = shift;
  
  my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sql->sth('role'), undef, ($role =~ s/\D//gr || undef, $role));
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such role [$role]!

TXT
    and return
    unless $r;
  
  my $u = $dbh->selectall_arrayref($sql->sth('role_users'), { Slice => {} }, ($r->{id}));
  $c->render(format=>'txt', text=><<TXT);
$pkg

All @{[scalar @$u]} users by role [$r->{name}]

@{[$c->dumper( $u)]}
TXT
}

sub role_routes {# все маршруты роли по запросу /myadmin/routes/:role
  my $c = shift;
  
   my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sql->sth('role'), undef, ($role =~ s/\D//gr || undef, $role));
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such role [$role]!

TXT
    and return
    unless $r;
  
  my $t = $dbh->selectall_arrayref($sql->sth('role_routes'), { Slice => {} }, ($r->{id}));
  $c->render(format=>'txt', text=><<TXT);
$pkg

All @{[scalar @$t]} routes by role [$r->{name}]

@{[$c->dumper( $t)]}
TXT
}


my @admin_routes_cols = qw(request namespace controller action name auth descr);
sub admin_routes {# from plugin!
  my $c = shift;
  my $prefix = $plugin_conf->{admin_routes}{prefix};
  my $trust = $plugin_conf->{admin_routes}{trust};
  my $ns = $plugin_conf->{namespace};

  my $t = <<TABLE;
/$prefix	$ns	admin	index	$prefix admin home	1	View main page
/$prefix/role/new/:name	$ns	admin	new_role	$prefix create role	1	Add new role by :name
/$prefix/roles	$ns	admin	roles	$prefix view roles	1	View roles table
/$prefix/roles/:user	$ns	admin	user_roles	$prefix roles of user	1	View roles of :user by id|login
/$prefix/role/:role/:user	$ns	admin	new_role_user	$prefix create ref role->user	1	Assign :user to :role by user.id|user.login and role.id|role.name.

/$prefix/route/new	$ns	admin	new_route	$prefix create route	1	Add new route by params: request,namespace, controller,....
/$prefix/routes	$ns	admin	routes	$prefix view routes	1	View routes table
/$prefix/routes/:role	$ns	admin	role_routes	$prefix routes of role	1	All routes of :role by id|name
/$prefix/route/:route/:role	$ns	admin	ref	$prefix create ref route->role	1	Assign :route with :role by route.id and role.id|role.name

/$prefix/user/new	$ns	admin	new_user	$prefix create user	1	Add new user by params: login,pass,...
/$prefix/user/new/:login/:pass	$ns	admin	new_user	$prefix create user st	1	Add new user by :login & :pass
/$prefix/users	$ns	admin	users	$prefix view users	1	View users table
/$prefix/users/:role	$ns	admin	role_users	$prefix users of role	1	View users of :role by id|name

get foo /sign/in	$ns	admin	sign	signin form	0	Login&pass form
post /sign/in	$ns	admin	sign	signin params	0	Auth by params
/sign/in/:login/:pass	$ns	admin	sign	signin stash	0	Auth by stash
/sign/out	$ns	admin	signout	go away	1	Exit

/$prefix/$trust/user/new/:login/:pass	$ns	admin	trust_new_user	$prefix/$trust !trust create user!	0	Add new user by :login & :pass and auto assign to role 'Admin' and assign to access this controller!

/$prefix/schema	$ns	install	schema	$prefix sql schema	0	Postgres SQL schema
/$prefix/schema/drop	$ns	install	schema_drop	$prefix drop schema	0	Postgres SQL schema remove
/$prefix/schema/flush	$ns	install	schema_flush	$prefix flush schema	0	Postgres SQL schema clean
/$prefix/install	$ns	install	manual	$prefix install	0	Manual

TABLE
  
  
  my @r = ();
  for my $line (grep /\S+/, split /\n/, $t) {
    my $r = {};
    @$r{@admin_routes_cols} = map($_ eq '' ? undef : $_, split /\t/, $line);
    push @r, $r;
  }
  
  return @r;
}


1;

__END__
sub routes000 {
  my $c = shift;
  
  $sth->{insert_routes} ||= $dbh->prepare(<<SQL);
insert into routes (@{[join ',', @admin_routes_cols]}) values (@{[join ',', map '?', @admin_routes_cols]}) returning *;
SQL

  local $dbh->{AutoCommit} = 0;
  #~ $dbh->begin_work;
  
    $c->render(format=>'txt', text=>"$pkg\n\n". $c->dumper([
  map($dbh->selectrow_hashref($sth->{insert_routes}, undef, @$_{@admin_routes_cols},), $c->admin_routes)]).<<TXT);

You must kill -HUP (reload/restart) your app! 

TXT
  
  $dbh->rollback;
}
