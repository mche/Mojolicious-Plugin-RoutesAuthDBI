package Mojolicious::Plugin::RoutesAuthDBI::Admin;
use Mojo::Base 'Mojolicious::Controller';
use Mojolicious::Plugin::RoutesAuthDBI::PgSQL;#  sth cache
use Exporter 'import'; 
our @EXPORT_OK = qw(load_user validate_user);

my $dbh; # one per class
my $pkg = __PACKAGE__;
my $init_conf;
my $sql;#sth hub

=pod
=encoding utf8

=head NAME

Mojolicious::Plugin::RoutesAuthDBI::Admin - is a mixed Mojolicious::Controller. It invoking from plugin module and might also using as standard Mojolicious::Controller. From plugin it controll access to routes trought sintax of ->over(...), see L<Mojolicious::Routes::Route#over>

=head1 SYNOPSIS

In plugin:
    
    $conf->{access}{namespace} = 'Mojolicious::Plugin::RoutesAuthDBI';
    $conf->{access}{controller} = 'Admin';
    my $class  = join '::', $conf->{namespace}, ucfirst(lc($conf->{controller}));
    require join '/', $conf->{access}{namespace} =~ s/::/\//gr, $conf->{access}{controller}.'.pm';# not use!
    $class->import( qw(load_user validate_user) );
    my $access = (bless $conf->{access}{access}, $module)->init_class;

For routing:

    $r->get('/myadmin')->over(<access>)->to('admin#index', namespace=>'Mojolicious::Plugin::RoutesAuthDBI',);

=head1 OPTIONS for access controller

    $app->plugin('RoutesAuthDBI', 
        dbh => $app->dbh,
        auth => {...},
        access => {< options below >},
    );

=over 4

=item * B<namespace> - default 'Mojolicious::Plugin::RoutesAuthDBI',

=item * B<controller> - default 'Admin',

Both above options determining the module which will play as manager of authentication, accessing and generate routing from DBI source.

=item * B<admin> - hashref: key I<prefix> => is prefix for admin urls of this module, key I<trust> => is a url subprefix for trust admin urls of this module. Optional.

    admin = > {prefix=>'myadmin', trust => 'foooobaaar'},

is admin urls like: /myadmin/foooobaaar/.....

By default:

    admin = > {prefix=>'admin', trust => $app->secrets->[0]},
    
    admin = {}, # empty hashref sets defaults above
    
    admin => undef, # disables routing of this module
    

=item * B<fail_auth_cb> = sub {my $c = shift;...}

This callback invoke when request need auth route but authentication was failure.

=item * B<fail_access_cb> = sub {my ($c, $route, $r_hash) = @_;...}

This callback invoke when request need auth route but access was failure. $route - L<Mojolicious::Routes::Route> object, $r_hash - route hashref db item.

=back

=head1 EXPORT SUBS

=over 4

=item * B<load_user($c, $uid)> - fetch user record from table users by COOKIES. Import for Mojolicious::Plugin::Authentication. Required.

=item * B<validate_user($c, $login, $pass, $extradata)> - fetch user record from table users by Mojolicious::Plugin::Authentication. Required.

=back


head1 METHODS NEEDS IN PLUGIN

=over 4

=item * B<init_class()> - make initialization of class vars: $dbh, $sql, $init_conf. Return $self object controller;

=item * B<admin_routes()> - builtin this access controller routes. Return array of hashrefs. Depends on conf options I<prefix> and I<trust>. Optional method.

=item * B<apply_route($self, $app, $r_hash)> - insert to app->routes an hash item $r_hash. Return new Mojolicious route;

=item * B<table_routes()> - fetch records from table routes. Return arrayref of hashrefs records.

=item * B<load_user_roles($self, $c, $uid)> - fetch records roles for auth user. Return hashref record.

=item * B<access_route($self, $c, $id1, $id2)> - make check access to route by $id1 for user roles ids $id2 arrayref. Return false for deny access or true - allow access.

=item * B<access_controller($self, $c, $r, $id2)> - make check access to route by special route record with request=NULL by $r->{namespace} and $r->{controller} for user roles ids $id2 arrayref. Return false for deny access or true - allow access to all actions of this controller.

=back

=cut

######################## PLUGIN SPECIFIC! ##########################################

sub init_class {# from plugin! init Class vars
	my $c = shift;
	my $args = {@_};
  $init_conf ||= $c;
  if ($c->{admin}) {
    $c->{admin}{prefix} =~ s/^\///;
    $c->{admin}{trust} =~ s/\W/-/g;
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
	$dbh->selectall_arrayref($sql->sth('user roles'), { Slice => {} }, ($uid));
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
  my $rt = $dbh->selectrow_hashref($sql->sth('route/controller'), undef, ($init_conf->{namespace}, $init_conf->{controller}));
  $rt ||= $dbh->selectrow_hashref($sql->sth('new_route'), undef, (undef, 'admin controller', $init_conf->{namespace}, $init_conf->{controller}, undef, 1, "Access to all $init_conf->{namespace}\::$init_conf->{controller} actions", undef, undef,));
    
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
  my $u =  $dbh->selectrow_hashref($sql->sth('user'), undef, ($user =~ /\D/ ? (undef, $user) : ($user, undef,)));
  
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
  my $r = $dbh->selectrow_hashref($sql->sth('role'), undef, ($role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

Can't create new role by only digits[$role] in name!

TXT
    and return
    unless $r && $role =~ /\w/;
  $r ||= $dbh->selectrow_hashref($sql->sth('new_role'), undef, ($role)) ;
  
  my $user = $c->stash('user') || $c->param('user');
  my $u =  $dbh->selectrow_hashref($sql->sth('user'), undef, ($user =~ /\D/ ? (undef, $user) : ($user, undef,)));
  
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

sub del_role_user {# удалить связь пользователя с ролью
  my $c = shift;
  
  my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sql->sth('role'), undef, ($role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such role [$role]!

TXT
    and return
    unless $r;

  my $user = $c->stash('user') || $c->param('user');
  my $u =  $dbh->selectrow_hashref($sql->sth('user'), undef, ($user =~ /\D/ ? (undef, $user) : ($user, undef,)));
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such user [$user]!

TXT
    and return
    unless $u;
  
  my $ref = $dbh->selectrow_hashref($sql->sth('del ref'), undef, ($r->{id}, $u->{id}));
  $c->render(format=>'txt', text=><<TXT)
$pkg

Success delete ref ROLE[$role]->USER[$user]!

@{[$c->dumper( $ref)]}
TXT
    and return
    if $ref;
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

There is no ref ROLE[$role]->USER[$user]!

TXT
  
}

sub disable_role {
  my $c = shift;
  my $a = shift // 1; # 0-enable 1 - disable
  my $k = {0=>'enable', 1=>'disable',};
  
  my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sql->sth('dsbl/enbl role'), undef, ($a, $role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such role [$role]!

TXT
    and return
    unless $r;
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

Success @{[$k->{$a}]} role!

@{[$c->dumper( $r)]}

TXT
}

sub enable_role {shift->disable_role(0);}


sub role_users {# все пользователи роли по запросу /myadmin/users/:role
  my $c = shift;
  
  my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sql->sth('role'), undef, ($role =~ /\D/ ? (undef, $role) : ($role, undef,)));
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
  my $r = $dbh->selectrow_hashref($sql->sth('role'), undef, ($role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such role [$role]!

TXT
    and return
    unless $r;
  
  my $t = $dbh->selectall_arrayref($sql->sth('role_routes'), { Slice => {} }, ($r->{id}));
  $c->render(format=>'txt', text=><<TXT);
$pkg

Total @{[scalar @$t]} routes by role [$r->{name}]

@{[$c->dumper( $t)]}
TXT
}


my @admin_routes_cols = qw(request namespace controller action name auth descr);
sub admin_routes {# from plugin!
  my $c = shift;
  my $prefix = $init_conf->{admin}{prefix};
  my $trust = $init_conf->{admin}{trust};
  my $ns = $init_conf->{namespace};

  my $t = <<TABLE;
/$prefix	$ns	admin	index	$prefix admin home	1	View main page
/$prefix/role/new/:name	$ns	admin	new_role	$prefix create role	1	Add new role by :name
/$prefix/role/del/:role/:user	$ns	admin	del_role_user	$prefix del ref role->user	1	Delete ref :user -> :role by user.id|user.login and role.id|role.name.
/$prefix/role/dsbl/:role	$ns	admin	disable_role	$prefix disable role->user	1	Disable :role by role.id|role.name.
/$prefix/role/enbl/:role	$ns	admin	enable_role	$prefix enable role->user	1	Enable :role by role.id|role.name.
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