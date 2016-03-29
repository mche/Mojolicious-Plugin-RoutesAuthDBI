package Mojolicious::Plugin::RoutesAuthDBI::Admin;
use Mojo::Base 'Mojolicious::Controller';

my $dbh;
my $sth;
my $pkg = __PACKAGE__;

sub new {
	my $self = shift->SUPER::new(@_);
	$dbh =  $self->app->dbh->{'main'};
        $sth = $self->app->sth->{'main'}{$pkg} ||= {};
	return $self;
}

sub home {
  my $c = shift;
  
   $c->render(format=>'txt', text=><<TXT);
Welcome $pkg!

1. Run create db schema:

\$ perl test-app.pl get /admin/schema 2>/dev/null | ~/postgres/bin/psql -d test

2. Run insert admin app routes to sql table:

\$ perl test-app.pl get /admin/routes/init

TXT
}

sub index {
  my $c = shift;
  
  #~ $c->render(format=>'txt', text=>__PACKAGE__ . " At home!!! ".$c->dumper( $c->session('auth_data')));
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

You are signed!
@{[$c->dumper( $c->auth_user)]}
TXT
    and return
    if $c->is_user_authenticated;
  
  $c->render(format=>'txt', text=>__PACKAGE__."\n\nYou are not signed!!! To sign in/up go to /sign/<login>/<pass>");
}

sub sign {
  my $c = shift;
  
  $c->authenticate($c->stash('login'), $c->stash('pass'))
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
  
  my $r = $dbh->selectrow_array("insert into users (login, pass) values (?,?) returning *;", undef, ($login, $pass));
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

Success sign up new user!
@{[$c->dumper( $r)]}
TXT
  
}


sub init_routes {
  my $c = shift;
  
  $sth->{insert_routes} ||= $dbh->prepare(<<SQL);
insert into routes (request, namespace, controller, action, name, auth, descr) values (?,?,?,?,?,?,?) returning *;
SQL
  
  local $dbh->{AutoCommit};
  $dbh->begin_work;
  my $ns = 'Mojolicious::Plugin::RoutesAuthDBI';
    $c->render(format=>'txt', text=>"$pkg\n\n". $c->dumper([
  map($dbh->selectrow_hashref($sth->{insert_routes}, undef, @$_),
  (
    [undef, $ns,'admin', undef,'admin controller', 1, 'Access to all Admin actions'],
    ['/admin', $ns,'admin','index','admin home', 1, 'View main page'],
    ['/admin/role/new/:name', $ns,'admin','new_role','new role', 1, 'Add new role by :name'],
    ['/admin/roles', $ns,'admin','roles','view roles', 1, 'View roles table'],
    ['/admin/roles/:user', $ns,'admin','user_roles','roles of user', 1, 'View roles of :user by id|login'],
    ['/admin/role/:role/:user', $ns,'admin','ref','ref role->user', 1, 'Assign :user to :role by user.id|user.login and role.id|role.name'],
    
    ['/admin/route/new', $ns,'admin','new_route','new route', 1, 'Add new route by params: request,namespace, controller,....'],
    ['/admin/routes', $ns,'admin','routes','view routes', 1, 'View routes table'],
    ['/admin/routes/:role', $ns,'admin','role_routes','routes of role', 1, 'View routes of :role by id|name'],
    ['/admin/route/:route/:role', $ns,'admin','ref','ref route->role', 1, 'Assign :route with :role by route.id and role.id|role.name'],
    
    ['/admin/user/new', $ns,'admin','new_user','sign up', 1, 'Add new user by params: login,pass,...'],
    ['/admin/user/new/:login/:pass', $ns,'admin','new_user','sign up', 1, 'Add new user by :login & :pass'],
    ['/admin/users', $ns,'admin','users','view users', 1, 'View users table'],
    ['/admin/users/:role', $ns,'admin','role_users','users of role', 1, 'View users of :role by id|name'],
    
    ['/sign/:login/:pass', $ns,'admin','sign','sign in & up', undef],
    ['/sign/out', $ns,'admin','signout','go away', 1],
  )),
    ]).<<TXT);

You must kill -HUP (reload/restart) your app! 

TXT
  
  $dbh->commit;
}

sub schema {
  my $c = shift;
  # ~/Mojolicious-Plugin-RoutesAuthDBI $ perl test-app.pl get /admin/schema 2>/dev/null | ~/postgres/bin/psql -d test
  $c->render(format=>'txt', text => join '', <Mojolicious::Plugin::RoutesAuthDBI::Admin::DATA>);
}

1;

__DATA__

CREATE SEQUENCE id;

CREATE TABLE routes (
    id integer default nextval('id'::regclass) not null primary key,
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


