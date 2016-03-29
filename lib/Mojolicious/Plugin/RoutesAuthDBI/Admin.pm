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

sub index {
  my $c = shift;
  
  #~ $c->render(format=>'txt', text=>__PACKAGE__ . " At home!!! ".$c->dumper( $c->session('auth_data')));
  
  $c->render(format=>'txt', text=>__PACKAGE__ . "\n\nYou are signed!!! ".$c->dumper( $c->auth_user))
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

sub init {
  my $c = shift;
  
  $c->render(format=>'txt', text=>__PACKAGE__ .<<TXT);
  
  This is first run of plugin RoutesAuthDBI!!!
  Go to URL  /admin/init for generate SQL route table for sample administration:

TXT
  
}

sub init_routes {
  my $c = shift;
  
  $sth->{insert_routes} ||= $dbh->prepare(<<SQL);
insert into routes (request, namespace, controller, action, name, auth) values (?,?,?,?,?,?) returning *;
SQL
  

  
    $c->render(format=>'txt', text=>__PACKAGE__ ."\n\n". $c->dumper([
  map($dbh->selectrow_hashref($sth->{insert_routes}, undef, @$_),
  (['/','Mojolicious::Plugin::RoutesAuthDBI','admin','index','admin home', undef],
    ['/sign/:login/:pass','Mojolicious::Plugin::RoutesAuthDBI','admin','sign','sign in & up', undef],
    ['/sign/out','Mojolicious::Plugin::RoutesAuthDBI','admin','signout','go away', 1],
  )),
    ]).<<TXT);

You must kill -HUP (reload/restart) your app! 

TXT
  
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
    request character varying not null,
    namespace character varying null,
    controller character varying not null,
    action character varying not null,
    name character varying not null,
    descr text,
    auth bit(1),
    disable bit(1),
    order_by int
);


