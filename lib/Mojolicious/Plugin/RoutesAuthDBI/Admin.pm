package Mojolicious::Plugin::RoutesAuthDBI::Admin;
use Mojo::Base 'Mojolicious::Controller';

my $dbh;
my $sth;
my $pkg = __PACKAGE__;
my $ns = 'Mojolicious::Plugin::RoutesAuthDBI';

sub new {
	my $self = shift->SUPER::new(@_);
	$dbh =  $self->app->dbh->{'main'};
        $sth = $self->app->sth->{'main'}{$pkg} ||= {};
	return $self;
}

sub install {
  my $c = shift;
  
   $c->render(format=>'txt', text=><<TXT);
Welcome $pkg!

Check <prefix> option for plugin on test-app.pl

1.  Run create db schema:

\$ perl test-app.pl get /<prefix>/schema 2>/dev/null | psql -d test

2. Go to trust url for admin-user creation :

\$ perl test-app.pl get /<prefix>/@{[$c->app->secrets->[0] =~ s/\W/-/gr]}/user/new/<login>/<pass>

User would be created, assigned to role 'Admin' and role 'Admin' assigned to pseudo-route that has access to all routes of this Controller!

TXT
}

sub index {
  my $c = shift;
  
  #~ $c->render(format=>'txt', text=>__PACKAGE__ . " At home!!! ".$c->dumper( $c->session('auth_data')));
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

You are signed as:
@{[$c->dumper( $c->auth_user)]}
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
  ($r = $dbh->selectrow_hashref("select * from users where login=?", undef, ($login)))
    and $c->render(format=>'txt', text=><<TXT)
$pkg

User already exists!

@{[$c->dumper( $r)]}
TXT
    and ($r->{not_new} = '!')
    and return $r;
  
  $r = $dbh->selectrow_hashref("insert into users (login, pass) values (?,?) returning *;", undef, ($login, $pass));
  
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
  my $rl = $dbh->selectrow_hashref("select * from roles where lower(name)=?", undef, ('admin'));
  $rl ||= $dbh->selectrow_hashref("insert into roles (name) values (?) returning *;", undef, ('admin'));
  
  # REF role->user
  my $ru = $dbh->selectrow_hashref("select * from refs where id1=? and id2=?;", undef, ($rl->{id}, $u->{id}));
  $ru ||= $dbh->selectrow_hashref("insert into refs (id1,id2) values (?,?) returning *;", undef, ($rl->{id}, $u->{id}));
  
  # ROUTE
  my $rt = $dbh->selectrow_hashref("select * from routes where namespace=? and lower(controller)=? and request is null and action is null", undef, ($ns, 'admin'));
  $rt ||= $dbh->selectrow_hashref("insert into routes (name, namespace, controller, auth, descr) values (?,?,?,?,?) returning *;", undef, ('admin controller', $ns, 'admin', 1, "Access to all $ns\::Admin.pm actions"));
    
    #REF route->role
  my $rr = $dbh->selectrow_hashref("select * from refs where id1=? and id2=?", undef, ($rt->{id}, $rl->{id}));
  $rr ||= $dbh->selectrow_hashref("insert into refs (id1,id2) values (?,?) returning *;", undef, ($rt->{id}, $rl->{id}));
  
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


my @admin_routes_cols = qw(request namespace controller action name auth descr);
sub admin_routes {
  my $c = shift;
  my $prefix = (shift || 'admin') =~ s/^\///r;
  my $trust = shift =~ s/\W/-/gr;

  my $t = <<TABLE;
	$ns	admin				1	Access to all $ns\::Admin.pm actions
/$prefix	$ns	admin	index	$prefix admin home	1	View main page
/$prefix/role/new/:name	$ns	admin	new_role	$prefix create role	1	Add new role by :name
/$prefix/roles	$ns	admin	roles	$prefix view roles	1	View roles table
/$prefix/roles/:user	$ns	admin	user_roles	$prefix roles of user	1	View roles of :user by id|login
/$prefix/role/:role/:user	$ns	admin	ref	$prefix create ref role->user	1	Assign :user to :role by user.id|user.login and role.id|role.name

/$prefix/route/new	$ns	admin	new_route	$prefix create route	1	Add new route by params: request,namespace, controller,....
/$prefix/routes	$ns	admin	routes	$prefix view routes	1	View routes table
/$prefix/routes/:role	$ns	admin	role_routes	$prefix routes of role	1	View routes of :role by id|name
/$prefix/route/:route/:role	$ns	admin	ref	$prefix create ref route->role	1	Assign :route with :role by route.id and role.id|role.name

/$prefix/user/new	$ns	admin	new_user	$prefix create user	1	Add new user by params: login,pass,...
/$prefix/user/new/:login/:pass	$ns	admin	new_user	$prefix create user st	1	Add new user by :login & :pass
/$prefix/users	$ns	admin	users	$prefix view users	1	View users table
/$prefix/users/:role	$ns	admin	role_users	$prefix users of role	1	View users of :role by id|name

get foo /sign/in	$ns	admin	sign	signin form	0	Login&pass form
post /sign/in	$ns	admin	sign	signin params	0	Auth by params
/sign/in/:login/:pass	$ns	admin	sign	signin stash	0	Auth by stash
/sign/out	$ns	admin	signout	go away	1	Exit

/$prefix/schema	$ns	admin	schema	$prefix sql schema	0	Postgres SQL schema
/$prefix/schema/drop	$ns	admin	schema_drop	$prefix drop schema	0	Postgres SQL schema remove
/$prefix/schema/flush	$ns	admin	schema_flush	$prefix flush schema	0	Postgres SQL schema clean
/$prefix/install	$ns	admin	install	$prefix install	0	Manual

TABLE
  
  $t .= <<TRUST if $trust;
/$prefix/$trust/user/new/:login/:pass	$ns	admin	trust_new_user	$prefix/$trust trust create user	0	Add new user by :login & :pass and auto assign to role 'Admin' and assign to access this controller!
TRUST
  
  
  my @r;
  for my $line (grep /\S+/, split /\n/, $t) {
    my $r = {};
    @$r{@admin_routes_cols} = map($_ eq '' ? undef : $_, split /\t/, $line);
    push @r, $r;
  }
  
  return @r;
}


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
        pass varchar not null
);
    
create table roles (
        id int default nextval('ID'::regclass) not null  primary key,
        ts timestamp without time zone default now() not null,
        name varchar not null unique
);

create table refs (
        id int default nextval('ID'::regclass) not null  primary key,
        ts timestamp without time zone default now() not null,
        id1 int not null,
        id2 int not null,
        unique(id1, id2)
);
create index on refs (id2);


