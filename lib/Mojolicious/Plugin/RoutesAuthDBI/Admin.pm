package Mojolicious::Plugin::RoutesAuthDBI::Admin;
use Mojo::Base 'Mojolicious::Controller';
use Mojolicious::Plugin::RoutesAuthDBI::SQL;#  sth cache

my $dbh;
my $pkg = __PACKAGE__;
my $namespace = 'Mojolicious::Plugin::RoutesAuthDBI';
my $plugin_conf;
my $sql;#sth cache

sub new {
	my $self = shift->SUPER::new(@_);
	$self->init;
	return $self;
}

######################## Plugin! ##########################################

sub init {# from plugin! init Class vars
	my $self = shift;
	my $args = {@_};
	$self->{dbh} ||= $dbh ||=  $args->{dbh};
	$dbh ||= $self->{dbh};
	$self->{sql} ||= $sql ||= $args->{sql} ||= bless [$dbh, {}], $namespace.'::SQL';#sth cache
	$sql ||= $self->{sql};
	return $self;
}

sub get_user {
	my ($c, $uid) = @_;
	$dbh->selectrow_hashref($sql->sth('user/id'), undef, ($uid));
}

sub validate_user {# plugin
  my ($c, $login, $pass, $extradata) = @_;
  if (my $u = $dbh->selectrow_hashref($sql->sth('user/login'), undef, ($login))) {
    return $u->{id}
      if $u->{pass} eq $pass  && !$u->{disable};
  }
  return undef;
}

sub plugin_routes {
  $dbh->selectall_arrayref($sql->sth('all routes'), { Slice => {} },);
}

sub plugin_user_roles {
	my ($c, $uid) = @_;
	$dbh->selectall_arrayref($sql->sth('user roles'), { Slice => {} }, ($uid));
}

sub access_route {
	my ($c, $id1, $id2,) = @_;
	return scalar $dbh->selectrow_array($sql->sth('cnt refs'), undef, ($id1, $id2));
}

sub access_controller {
	my ($c, $r, $id2,) = @_;
	return scalar $dbh->selectrow_array($sql->sth('access controller'), undef, ($r->{controller}, $r->{namespace},  $id2));
}

################################ END PLUGIN #################################

sub install {
  my $c = shift;
  
   $c->render(format=>'txt', text=><<TXT);
Welcome $pkg controller!

1. Edit test-app.pl and Config.pm to define DBI->connect dsn, url admin prefix and trust subprefix.
------------------------



2. View admin routes:
------------------------
\$ perl test-app.pl routes



3.  Run create db schema:
-----------------------------
\$ perl test-app.pl get /$plugin_conf->{prefix}/schema 2>/dev/null | psql -d <dbname>


4. Go to trust url for admin-user creation :
------------------------------------------------
\$ perl test-app.pl get /$plugin_conf->{prefix}/$plugin_conf->{trust}/user/new/<login>/<pass>

User will be created and assigned to role 'Admin' . Role 'Admin' assigned to pseudo-route that has access to all routes of this controller!



5. Go to /sign/in/<login>/<pass>
-------------------------------------



6. Go to /$plugin_conf->{prefix}
------------------------------------


Administration of system ready!

TXT
}

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
  my $rt = $dbh->selectrow_hashref($sql->sth('route/controller'), undef, ($namespace, 'admin'));
  $rt ||= $dbh->selectrow_hashref($sql->sth('new_route'), undef, (undef, 'admin controller', $namespace, 'admin', undef, 1, "Access to all $namespace\::Admin.pm actions", undef, undef,));
    
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
  $plugin_conf ||= $c;
  $plugin_conf->{prefix} =~ s/^\///;
  my $prefix = $plugin_conf->{prefix};
  my $trust = $plugin_conf->{trust} =~ s/\W/-/gr;
  my $namespace = $plugin_conf->{namespace};

  my $t = <<TABLE;
/$prefix	$namespace	admin	index	$prefix admin home	1	View main page
/$prefix/role/new/:name	$namespace	admin	new_role	$prefix create role	1	Add new role by :name
/$prefix/roles	$namespace	admin	roles	$prefix view roles	1	View roles table
/$prefix/roles/:user	$namespace	admin	user_roles	$prefix roles of user	1	View roles of :user by id|login
/$prefix/role/:role/:user	$namespace	admin	new_role_user	$prefix create ref role->user	1	Assign :user to :role by user.id|user.login and role.id|role.name.

/$prefix/route/new	$namespace	admin	new_route	$prefix create route	1	Add new route by params: request,namespace, controller,....
/$prefix/routes	$namespace	admin	routes	$prefix view routes	1	View routes table
/$prefix/routes/:role	$namespace	admin	role_routes	$prefix routes of role	1	All routes of :role by id|name
/$prefix/route/:route/:role	$namespace	admin	ref	$prefix create ref route->role	1	Assign :route with :role by route.id and role.id|role.name

/$prefix/user/new	$namespace	admin	new_user	$prefix create user	1	Add new user by params: login,pass,...
/$prefix/user/new/:login/:pass	$namespace	admin	new_user	$prefix create user st	1	Add new user by :login & :pass
/$prefix/users	$namespace	admin	users	$prefix view users	1	View users table
/$prefix/users/:role	$namespace	admin	role_users	$prefix users of role	1	View users of :role by id|name

get foo /sign/in	$namespace	admin	sign	signin form	0	Login&pass form
post /sign/in	$namespace	admin	sign	signin params	0	Auth by params
/sign/in/:login/:pass	$namespace	admin	sign	signin stash	0	Auth by stash
/sign/out	$namespace	admin	signout	go away	1	Exit

/$prefix/schema	$namespace	admin	schema	$prefix sql schema	0	Postgres SQL schema
/$prefix/schema/drop	$namespace	admin	schema_drop	$prefix drop schema	0	Postgres SQL schema remove
/$prefix/schema/flush	$namespace	admin	schema_flush	$prefix flush schema	0	Postgres SQL schema clean
/$prefix/install	$namespace	admin	install	$prefix install	0	Manual

/$prefix/$trust/user/new/:login/:pass	$namespace	admin	trust_new_user	$prefix/$trust !trust create user!	0	Add new user by :login & :pass and auto assign to role 'Admin' and assign to access this controller!
TABLE
  
  
  my @r = ();
  for my $line (grep /\S+/, split /\n/, $t) {
    my $r = {};
    @$r{@admin_routes_cols} = map($_ eq '' ? undef : $_, split /\t/, $line);
    push @r, $r;
  }
  
  return @r;
}

=pod
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
=cut

sub schema {
  my $c = shift;
  # ~/Mojolicious-Plugin-RoutesAuthDBI $ perl test-app.pl get /admin/schema 2>/dev/null | ~/postgres/bin/psql -d test
  $c->render(format=>'txt', text => join '', <Mojolicious::Plugin::RoutesAuthDBI::Admin::DATA>);
}

sub schema_drop {
  my $c = shift;
  
  $c->render(format=>'txt', text => <<TXT);

drop table refs;
drop table users;
drop table roles;
drop table routes;
drop sequence ID;

TXT
}

sub schema_flush {
  my $c = shift;
  
  $c->render(format=>'txt', text => <<TXT);

delete from refs;
delete from users;
delete from roles;
delete from routes;

TXT
}

1;

__DATA__


CREATE SEQUENCE ID;-- one sequence for all tables id

CREATE TABLE routes (
    id integer default nextval('ID'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    request character varying null,
    namespace character varying null,
    controller character varying not null,
    action character varying null,
    name character varying not null,
    descr text,
    auth bit(1),
    disable bit(1),
    order_by int
);

create table users (
        id int default nextval('ID'::regclass) not null  primary key,
        ts timestamp without time zone default now() not null,
        login varchar not null unique,
        pass varchar not null,
	disable bit(1)
);
    
create table roles (
        id int default nextval('ID'::regclass) not null  primary key,
        ts timestamp without time zone default now() not null,
        name varchar not null unique,
	disable bit(1)
);

create table refs (
        id int default nextval('ID'::regclass) not null  primary key,
        ts timestamp without time zone default now() not null,
        id1 int not null,
        id2 int not null,
        unique(id1, id2)
);
create index on refs (id2);


