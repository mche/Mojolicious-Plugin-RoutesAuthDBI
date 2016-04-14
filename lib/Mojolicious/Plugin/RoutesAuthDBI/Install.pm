package Mojolicious::Plugin::RoutesAuthDBI::Install;
use Mojo::Base 'Mojolicious::Controller';
use DBIx::POS;

my $sql = DBIx::POS->instance(__FILE__);

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS used.

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Install - is a Mojolicious::Controller for installation instructions. DB schema (PostgreSQL) and sample app.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 Manual

    $ perl -e "use Mojo::Base 'Mojolicious'; __PACKAGE__->new()->start(); sub startup {shift->routes->route('/')->to('install#manual', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');}" get / 2>/dev/null

=head1 DB schema (postgresql)

=head2 View schema

    $ perl -e "use Mojo::Base 'Mojolicious'; __PACKAGE__->new()->start(); sub startup {shift->routes->route('/')->to('install#schema', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');}" get / 2>/dev/null
    

=head2 Apply schema

    $ perl -e "use Mojo::Base 'Mojolicious'; __PACKAGE__->new()->start(); sub startup {shift->routes->route('/')->to('install#schema', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');}" get / 2>/dev/null | psql -d <dbname>


=head1 Sample test-app.pl

    $ perl -e "use Mojo::Base 'Mojolicious'; __PACKAGE__->new()->start(); sub startup {shift->routes->route('/')->to('install#test_app', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');}" get / 2>/dev/null > test-app.pl
    

=head1 Define DBI->connect(.........) and some plugin options in test-app.pl

=head1 Check list of admin routes:

    $ perl test-app.pl routes

=head1 Start app

    $ perl test-app.pl daemon

=head1 Trust url for admin-user creation:

    $ perl test-app.pl get /<pluginconf->{admin}{prefix}>/<pluginconf->{admin}{trust}>/user/new/<new admin login>/<admin pass> 2>/dev/null

=head1 Sign in by browser:

Go to http://127.0.0.1:3000/sign/in/<new admin login>/<admin pass>

=head1 Admin index:

Go to http://127.0.0.1:3000/<pluginconf->{admin}{prefix}>

Administration of system ready!

=cut

sub manual {
  my $c = shift;
  
   $c->render(format=>'txt', text=><<'TXT');
Welcome  Mojolicious::Plugin::RoutesAuthDBI !

1. Apply db schema by command:
------------

$ perl -e "use Mojo::Base 'Mojolicious'; __PACKAGE__->new()->start(); sub startup {shift->routes->route('/')->to('install#schema', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');}" get / 2>/dev/null | psql -d <dbname>


2. Create test-app.pl and  define in them DBI->connect(...) and some plugin options:
------------

$ perl -e "use Mojo::Base 'Mojolicious'; __PACKAGE__->new()->start(); sub startup {shift->routes->route('/')->to('install#test_app', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');}" get / 2>/dev/null > test-app.pl

3. View admin routes:
------------

$ perl test-app.pl routes


4. Start app:
------------

$ perl test-app.pl daemon


5. Go to trust url for admin-user creation :
------------

$ perl test-app.pl get /<pluginconf->{admin}{prefix}>/<pluginconf->{admin}{trust}>/admin/new/<new admin login>/<admin pass>

User will be created and assigned to role 'Admin' . Role 'Admin' assigned to pseudo-route that has access to all routes of this controller!



6. Go to http://127.0.0.1:3000/sign/in/<new admin login>/<admin pass>
------------



7. Go to http://127.0.0.1:3000/<plugiconf->{admin}{prefix}>
------------


Administration of system ready!

TXT
}

sub test_app {
  my $c = shift;
  $c->render(format=>'txt', text => <<'TXT');
use Mojo::Base 'Mojolicious';
use DBI;

has dbh => sub { DBI->connect("DBI:Pg:dbname=<dbname>;", "postgres", undef); };

sub startup {
  my $app = shift;
  # $app->plugin(Config =>{file => 'Config.pm'});
  $app->plugin('RoutesAuthDBI',
    dbh=>$app->dbh,
    auth=>{current_user_fn=>'auth_user'},
    # access=> {},
    admin=>{prefix=>'myadmin', trust=>'fooobaaar',},
  );
}

__PACKAGE__->new()->start();
TXT
}

=pod

=head1 DB design

=over 4

=item * B<Sequence>

=name schema.sequence

=desc

=sql

  CREATE SEQUENCE ID;-- one sequence for all tables id

=item * B<Routes>

=name schema.routes

=desc

=sql

  CREATE TABLE routes (
    id integer default nextval('ID'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    request character varying not null,
    name character varying not null unique,
    descr text null,
    auth bit(1) null,
    disable bit(1) null,
    order_by int null
  );

=item * B<Namespaces>

=name schema.namespaces

=desc

=sql

  create table namespaces (
    id integer default nextval('ID'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    namespace character varying not null unique,
    descr text null
  );

=item * B<Controllers>

=name schema.controllers

=desc

=sql

  create table controllers (
    id integer default nextval('ID'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    controller character varying not null,
    descr text null
  );

=item * B<Actions>

=name schema.actions

=desc

=sql

  create table actions (
    id integer default nextval('ID'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    action character varying not null,
    callback text null,
    descr text null
  );

=item * B<Users>

=name schema.users

=desc

=sql

  create table users (
    id int default nextval('ID'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    login varchar not null unique,
    pass varchar not null,
    disable bit(1)
  );

=item * B<Roles>

=name schema.roles

=desc

=sql

  create table roles (
    id int default nextval('ID'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    name varchar not null unique,
    disable bit(1)
  );

=item * B<Refs>

=name schema.refs

=desc

=sql

  create table refs (
    id int default nextval('ID'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    id1 int not null,
    id2 int not null,
    unique(id1, id2)
  );
  create index on refs (id2);

=back

=head1 Drop schema

=name schema.drop

=desc

=sql

    drop table refs;
    drop table users;
    drop table roles;
    drop table routes;
    drop table controllers;
    drop table actions;
    drop table namespaces;
    drop sequence ID;

=cut

sub schema {
  my $c = shift;
  #~ $c->render(format=>'txt', text => join '', <Mojolicious::Plugin::RoutesAuthDBI::Install::DATA>);
  $c->render(format=>'txt', text => <<TXT);
$sql->{'schema.sequence'}

$sql->{'schema.routes'}

$sql->{'schema.namespaces'}

$sql->{'schema.controllers'}

$sql->{'schema.actions'}

$sql->{'schema.users'}

$sql->{'schema.roles'}

$sql->{'schema.refs'}

TXT
}

sub schema_drop {
  my $c = shift;
  
  $c->render(format=>'txt', text => <<TXT);
$sql->{'schema.drop'}

TXT
}

sub schema_flush {
  my $c = shift;
  
  $c->render(format=>'txt', text => <<TXT);

delete from refs;
delete from users;
delete from roles;
delete from routes;
delete from controllers;
delete from namespaces;
delete from actions;

TXT
}

1;

__DATA__


