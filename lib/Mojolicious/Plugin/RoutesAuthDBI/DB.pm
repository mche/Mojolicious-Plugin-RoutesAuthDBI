package Mojolicious::Plugin::RoutesAuthDBI::DB;
use Mojo::Base 'Mojolicious::Controller';
use DBIx::POS::Template;

my $sql = DBIx::POS::Template->new(__FILE__);

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::DB

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::DB - DB schema (PostgreSQL).

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 DB design

=head2 Schema

=name schema

=desc Отдельная схема

=sql

  
  CREATE SCHEMA IF NOT EXISTS "{% $schema %}";
  set local search_path = "{% $schema %}";

=head2 Sequence

=name sequence

=desc последовательность для всех

=sql

  -- you may change schema name for PostgreSQL objects
  
  CREATE SEQUENCE "{% $schema %}".ID;-- one sequence for all tables id

=head2 Routes table

=name routes

=desc

=sql

  CREATE TABLE "{% $schema %}".routes (
    id integer default nextval('"{% $schema %}".ID'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    request character varying not null,
    name character varying not null unique,
    descr text null,
    auth varchar null,-- was bit(1): alter table "{% $schema %}".routes alter column auth type varchar;
    disable bit(1) null,
    -- interval_ts - смещение ts (seconds) для приоритета маршрута, т.е. влияет на сортровку маршрутов
    interval_ts int null -- was order_by int null; alter table "{% $schema %}".routes rename column order_by to interval_ts;
  );

=head2 Namespaces table

=name namespaces

=desc

=sql

  create table "{% $schema %}".namespaces (
    id integer default nextval('"{% $schema %}".ID'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    namespace character varying not null unique,
    descr text null,
    app_ns bit(1) null, -- alter table "{% $schema %}".namespaces add column app_ns bit(1) null;
    -- interval_ts - смещение ts (seconds) для приоритета namespace
    interval_ts int null -- alter table "{% $schema %}".namespaces add column interval_ts int null;
  );

=head2 Controllers table

=name controllers

=desc

=sql

  create table "{% $schema %}".controllers (
    id integer default nextval('"{% $schema %}".ID'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    controller character varying not null,
    descr text null
  );

=head2 Actions table

=name actions

=desc

=sql

  create table "{% $schema %}".actions (
    id integer default nextval('"{% $schema %}".ID'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    action character varying not null,
    callback text null,
    descr text null
  );

=head2 Users table

=name users

=desc

=sql

  create table "{% $schema %}".users (
    id int default nextval('"{% $schema %}".ID'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    login varchar not null unique,
    pass varchar not null,
    disable bit(1)
  );

=head2 Roles table

=name roles

=desc

=sql

  create table "{% $schema %}".roles (
    id int default nextval('"{% $schema %}".ID'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    name varchar not null unique,
    disable bit(1)
  );

=head2 Refs table

=name refs

=desc

=sql

  create table "{% $schema %}".refs (
    id int default nextval('"{% $schema %}".ID'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    id1 int not null,
    id2 int not null,
    unique(id1, id2)
  );
  create index on "{% $schema %}".refs (id2);

=cut


sub schema {
  my $c = shift;
  #~ $c->render(format=>'txt', text => join '', <Mojolicious::Plugin::RoutesAuthDBI::Install::DATA>);
  my $schema = $c->stash('schema') || $c->param('schema') || 'public';
  #~ my $schema2 = qq{"$schema".} if $schema;
  $c->render(format=>'txt', text => <<TXT);
@{[$schema ? $sql->{'schema'}->template(schema => $schema) : '']}

@{[$sql->{'sequence'}->template(schema => $schema)]}

@{[$sql->{'routes'}->template(schema => $schema)]}

@{[$sql->{'namespaces'}->template(schema => $schema)]}

@{[$sql->{'controllers'}->template(schema => $schema)]}

@{[$sql->{'actions'}->template(schema => $schema)]}

@{[$sql->{'users'}->template(schema => $schema)]}

@{[$sql->{'roles'}->template(schema => $schema)]}

@{[$sql->{'refs'}->template(schema => $schema)]}

TXT
}

=pod

=head1 Drop

=name drop

=desc

=sql

    drop table "{% $schema %}".refs;
    drop table "{% $schema %}".users;
    drop table "{% $schema %}".roles;
    drop table "{% $schema %}".routes;
    drop table "{% $schema %}".controllers;
    drop table "{% $schema %}".actions;
    drop table "{% $schema %}".namespaces;
    drop sequence "{% $schema %}".ID;


=cut

sub schema_drop {
  my $c = shift;
  my $schema = $c->stash('schema') || $c->param('schema');
  $schema = qq{"$schema".} if $schema;
  $c->render(format=>'txt', text => <<TXT);
@{[$sql->{'drop'}->template(schema => $schema)]}

TXT
}

=pod

=head1 Flush

=name flush

=desc

=sql

  delete from "{% $schema %}".refs;
  delete from "{% $schema %}".users;
  delete from "{% $schema %}".roles;
  delete from "{% $schema %}".routes;
  delete from "{% $schema %}".controllers;
  delete from "{% $schema %}".namespaces;
  delete from "{% $schema %}".actions;


=cut

sub schema_flush {
  my $c = shift;
  my $schema = $c->stash('schema') || $c->param('schema');
  $schema = qq{"$schema".} if $schema;
  $c->render(format=>'txt', text => <<TXT);

@{[$sql->{'flush'}->template(schema => $schema)]}

TXT
}

1;

__DATA__


