package Mojolicious::Plugin::RoutesAuthDBI::Install;
use Mojo::Base 'Mojolicious::Controller';
use DBIx::POS::Template;

my $sql = DBIx::POS::Template->new(__FILE__);

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::Install

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Install - is a Mojolicious::Controller for installation instructions. DB schema (PostgreSQL) and sample app.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 Manual

  $ read -d '' CODE <<PERL; perl -e "$CODE" get /man
  use Mojo::Base 'Mojolicious';
  sub startup {
    shift->routes->route('/man')
      ->to('install#manual', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');
  }
  __PACKAGE__->new()->start();
  PERL

=head1 DB schema (postgresql)

=head2 View schema (define the postgresql schema name)

  $ read -d '' CODE <<PERL; perl -e "$CODE" get /schema/<name> #
  use Mojo::Base 'Mojolicious';
  sub startup {
    shift->routes->route('/schema/:schema')
      ->to('install#schema', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');
  }
  __PACKAGE__->new()->start();
  PERL


=head2 Apply schema (define the postgresql schema name)

  $ read -d '' CODE <<PERL; perl -e "$CODE" get /schema/<name> 2>/dev/null | psql -d <dbname> #
  use Mojo::Base 'Mojolicious';
  sub startup {
    shift->routes->route('/schema/:schema')
      ->to('install#schema', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');
  }
  __PACKAGE__->new()->start();
  PERL


=head1 Sample app

  $ read -d '' CODE <<PERL; perl -e "$CODE" get /app 2>/dev/null > test-app.pl
  use Mojo::Base 'Mojolicious';
  sub startup {
    shift->routes->route('/app')
      ->to('install#test_app', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');
  }
  __PACKAGE__->new()->start();
  PERL

=name sample.app

=desc 

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

=sql

  --

=head1 Define DBI->connect(...) and some plugin options in test-app.pl

=head1 Check list of admin routes:

    $ perl test-app.pl routes

=head1 Start app

    $ perl test-app.pl daemon

=head1 Trust url for admin-user creation:

    $ perl test-app.pl get /<pluginconf->{admin}{prefix}>/<pluginconf->{admin}{trust}>/user/new/<new admin login>/<admin pass> 2>/dev/null

User will be created and assigned to role 'Admin' . Role 'Admin' assigned to namespace 'Mojolicious::Plugin::RoutesAuthDBI' that has access to all admin controller routes!

=head1 Sign in on browser

http://127.0.0.1:3000/sign/in/<new admin login>/<admin pass>

=head1 Administration of system ready!

=cut

sub manual {
  my $c = shift;
  
   $c->render(format=>'txt', text=><<'TXT');
Welcome  Mojolicious::Plugin::RoutesAuthDBI !

1. Apply db schema by command (define the postgresql schema name):
------------

$ perl -e "use Mojo::Base 'Mojolicious'; __PACKAGE__->new()->start(); sub startup {shift->routes->route('/schema/:schema')->to('install#schema', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');}" get /schema/public 2>/dev/null | psql -d <dbname> # here set public pg schema!


2. Create test-app.pl and then define in them DBI->connect(...) and some plugin options:
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

User will be created and assigned to role 'Admin' . Role 'Admin' assigned to namespace 'Mojolicious::Plugin::RoutesAuthDBI' that has access to all admin controller routes!


6. Go to http://127.0.0.1:3000/sign/in/<new admin login>/<admin pass>
------------


Administration of system ready!

TXT
}


sub test_app {
  my $c = shift;
  my $code = $sql->{'sample.app'}->desc;
  $c->render(format=>'txt', text => <<TXT);
$code
TXT
}

=pod

=head1 DB design

=over 4

=item * B<Schema name>

=name schema.name

=desc Отдельная схема

=sql

  
  CREATE SCHEMA IF NOT EXISTS "{% $schema %}";
  set local search_path = "{% $schema %}";

=item * B<Sequence>

=name schema.sequence

=desc последовательность

=sql

  -- you may change schema name for PostgreSQL objects
  
  CREATE SEQUENCE {% $schema %}ID;-- one sequence for all tables id

=item * B<Routes>

=name schema.routes

=desc

=sql

  CREATE TABLE {% $schema %}routes (
    id integer default nextval('{% $schema %}ID'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    request character varying not null,
    name character varying not null unique,
    descr text null,
    auth varchar null,-- was bit(1): alter table {% $schema %}routes alter column auth type varchar;
    disable bit(1) null,
    -- interval_ts - смещение ts (seconds) для приоритета маршрута, т.е. влияет на сортровку маршрутов
    interval_ts int null -- was order_by int null; alter table {% $schema %}routes rename column order_by to interval_ts;
  );

=item * B<Namespaces>

=name schema.namespaces

=desc

=sql

  create table {% $schema %}namespaces (
    id integer default nextval('{% $schema %}ID'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    namespace character varying not null unique,
    descr text null,
    app_ns bit(1) null, -- alter table {% $schema %}namespaces add column app_ns bit(1) null;
    -- interval_ts - смещение ts (seconds) для приоритета namespace
    interval_ts int null -- alter table {% $schema %}namespaces add column interval_ts int null;
  );

=item * B<Controllers>

=name schema.controllers

=desc

=sql

  create table {% $schema %}controllers (
    id integer default nextval('{% $schema %}ID'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    controller character varying not null,
    descr text null
  );

=item * B<Actions>

=name schema.actions

=desc

=sql

  create table {% $schema %}actions (
    id integer default nextval('{% $schema %}ID'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    action character varying not null,
    callback text null,
    descr text null
  );

=item * B<Users>

=name schema.users

=desc

=sql

  create table {% $schema %}users (
    id int default nextval('{% $schema %}ID'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    login varchar not null unique,
    pass varchar not null,
    disable bit(1)
  );

=item * B<Roles>

=name schema.roles

=desc

=sql

  create table {% $schema %}roles (
    id int default nextval('{% $schema %}ID'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    name varchar not null unique,
    disable bit(1)
  );

=item * B<Refs>

=name schema.refs

=desc

=sql

  create table {% $schema %}refs (
    id int default nextval('{% $schema %}ID'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    id1 int not null,
    id2 int not null,
    unique(id1, id2)
  );
  create index on {% $schema %}refs (id2);

=back

=cut


sub schema {
  my $c = shift;
  #~ $c->render(format=>'txt', text => join '', <Mojolicious::Plugin::RoutesAuthDBI::Install::DATA>);
  my $schema = $c->stash('schema') || $c->param('schema');
  my $schema2 = qq{"$schema".} if $schema;
  $c->render(format=>'txt', text => <<TXT);
@{[$schema ? $sql->{'schema.name'}->template(schema => $schema) : '']}

@{[$sql->{'schema.sequence'}->template(schema => $schema2)]}

@{[$sql->{'schema.routes'}->template(schema => $schema2)]}

@{[$sql->{'schema.namespaces'}->template(schema => $schema2)]}

@{[$sql->{'schema.controllers'}->template(schema => $schema2)]}

@{[$sql->{'schema.actions'}->template(schema => $schema2)]}

@{[$sql->{'schema.users'}->template(schema => $schema2)]}

@{[$sql->{'schema.roles'}->template(schema => $schema2)]}

@{[$sql->{'schema.refs'}->template(schema => $schema2)]}

TXT
}

=pod

=head1 Drop schema

=name schema.drop

=desc

=sql

    drop table {% $schema %}refs;
    drop table {% $schema %}users;
    drop table {% $schema %}roles;
    drop table {% $schema %}routes;
    drop table {% $schema %}controllers;
    drop table {% $schema %}actions;
    drop table {% $schema %}namespaces;
    drop sequence {% $schema %}ID;


=cut

sub schema_drop {
  my $c = shift;
  my $schema = $c->stash('schema') || $c->param('schema');
  $schema = qq{"$schema".} if $schema;
  $c->render(format=>'txt', text => <<TXT);
@{[$sql->{'schema.drop'}->template(schema => $schema)]}

TXT
}

=pod

=head1 Flush schema

=name schema.flush

=desc

=sql

  delete from {% $schema %}refs;
  delete from {% $schema %}users;
  delete from {% $schema %}roles;
  delete from {% $schema %}routes;
  delete from {% $schema %}controllers;
  delete from {% $schema %}namespaces;
  delete from {% $schema %}actions;


=cut

sub schema_flush {
  my $c = shift;
  my $schema = $c->stash('schema') || $c->param('schema');
  $schema = qq{"$schema".} if $schema;
  $c->render(format=>'txt', text => <<TXT);

@{[$sql->{'schema.flush'}->template(schema => $schema)]}

TXT
}

1;

__DATA__


