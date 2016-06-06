package Mojolicious::Plugin::RoutesAuthDBI::Schema;
use Mojo::Base 'Mojolicious::Controller';
use DBIx::POS::Template;

my $defaults = {
  schema => "public",
  sequence => '"public"."ID"',
  tables => {
    routes => 'routes',
    refs=>'refs',
    users => 'users',
    profiles => 'profiles',
    roles =>'roles',
    actions => 'actions',
    controllers => 'controllers',
    namespaces => 'namespaces',
  },
  
};
my $sql = DBIx::POS::Template->new(__FILE__, template=>$defaults,);

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::Schema

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Schema - DB schema (PostgreSQL).

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
  
  CREATE SEQUENCE {% $sequence %};-- one sequence for all tables id

=head2 Routes table

=name routes

=desc

=sql

  CREATE TABLE "{% $schema %}"."{% $tables{routes} %}" (
    id integer default nextval('{% $sequence %}'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    request character varying not null,
    name character varying not null unique,
    descr text null,
    auth varchar null,
    -- was bit(1): alter table "{% $schema %}"."{% $tables{routes} %}" alter column auth type varchar;
    disable bit(1) null,
    -- interval_ts - смещение ts (seconds) для приоритета маршрута, т.е. влияет на сортровку маршрутов
    interval_ts int null
    -- was order_by int null; alter table "{% $schema %}"."{% $tables{routes} %}" rename column order_by to interval_ts;
  );

=head2 Namespaces table

=name namespaces

=desc

=sql

  create table "{% $schema %}"."{% $tables{namespaces} %}" (
    id integer default nextval('{% $sequence %}'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    namespace character varying not null unique,
    descr text null,
    -- alter table "{% $schema %}"."{% $tables{namespaces} %}" add column app_ns bit(1) null;
    app_ns bit(1) null,
    -- interval_ts - смещение ts (seconds) для приоритета namespace
    interval_ts int null
    -- alter table "{% $schema %}"."{% $tables{namespaces} %}" add column interval_ts int null;
  );

=head2 Controllers table

=name controllers

=desc

=sql

  create table "{% $schema %}"."{% $tables{controllers} %}" (
    id integer default nextval('{% $sequence %}'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    controller character varying not null,
    descr text null
  );

=head2 Actions table

=name actions

=desc

=sql

  create table "{% $schema %}"."{% $tables{actions} %}" (
    id integer default nextval('{% $sequence %}'::regclass) not null primary key,
    ts timestamp without time zone default now() not null,
    action character varying not null,
    callback text null,
    descr text null
  );

=head2 Users table

=name users

=desc

Its logins table

=sql

  create table "{% $schema %}"."{% $tables{users} %}" (
    id int default nextval('{% $sequence %}'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    login varchar not null unique,
    pass varchar not null,
    disable bit(1)
  );

=head2 Profiles table

=name profiles

=desc 

=sql

  create table "{% $schema %}"."{% $tables{profiles} %}" (
    id int default nextval('{% $sequence %}'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    disable bit(1)
  );

=head2 Roles table

=name roles

=desc

=sql

  create table "{% $schema %}"."{% $tables{roles} %}" (
    id int default nextval('{% $sequence %}'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    name varchar not null unique,
    disable bit(1)
  );

=head2 Refs table

=name refs

=desc

Связи

=sql

  create table "{% $schema %}"."{% $tables{refs} %}" (
    id int default nextval('{% $sequence %}'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    id1 int not null,
    id2 int not null,
    unique(id1, id2)
  );
  create index on "{% $schema %}".refs (id2);

=cut


sub _vars {
  my $c = shift;
  my $template = {};

  for my $var (keys %$defaults) {
    $template->{$var} = $c->stash($var) || $c->param($var)
      and next
      unless  ref $defaults->{$var};
      
      $template->{$var} = { map {
      my $val = $c->stash($_) || $c->param($_);
      $val ? ($_ => $val) : ();
    
    } keys %{$defaults->{$var}}  };
  }
  $template;
}

sub schema {
  my $c = shift;
  #~ $c->render(format=>'txt', text => join '', <Mojolicious::Plugin::RoutesAuthDBI::Install::DATA>);
  my $template = $c->_vars;
  
  #~ my $schema2 = qq{"$schema".} if $schema;
  $c->render(format=>'txt', text => <<TXT);
@{[$sql->{'schema'}->template(%$template)]}

@{[$sql->{'sequence'}->template(%$template)]}

@{[$sql->{'routes'}->template(%$template)]}

@{[$sql->{'namespaces'}->template(%$template)]}

@{[$sql->{'controllers'}->template(%$template)]}

@{[$sql->{'actions'}->template(%$template)]}

@{[$sql->{profiles}->template(%$template)]}

@{[$sql->{'users'}->template(%$template)]}

@{[$sql->{'roles'}->template(%$template)]}

@{[$sql->{'refs'}->template(%$template)]}

TXT
}

=pod

=head1 Drop

=name drop

=desc

=sql

    drop table "{% $schema %}"."{% $tables{refs} %}";
    drop table "{% $schema %}"."{% $tables{users} %}";
    drop table "{% $schema %}"."{% $tables{profiles} %}";
    drop table "{% $schema %}"."{% $tables{roles} %}";
    drop table "{% $schema %}"."{% $tables{routes} %}";
    drop table "{% $schema %}"."{% $tables{controllers} %}";
    drop table "{% $schema %}"."{% $tables{actions} %}";
    drop table "{% $schema %}"."{% $tables{namespaces} %}";
    drop sequence {% $sequence %};


=cut

sub schema_drop {
  my $c = shift;
  my $template = $c->_vars;
  #~ $schema = qq{"$schema".} if $schema;
  $c->render(format=>'txt', text => <<TXT);
@{[$sql->{'drop'}->template(%$template)]}

TXT
}

=pod

=head1 Flush

=name flush

=desc

=sql

  delete from "{% $schema %}"."{% $tables{refs} %}";
  delete from "{% $schema %}"."{% $tables{users} %}";
  delete from "{% $schema %}"."{% $tables{profiles} %}";
  delete from "{% $schema %}"."{% $tables{roles} %}";
  delete from "{% $schema %}"."{% $tables{routes} %}";
  delete from "{% $schema %}"."{% $tables{controllers} %}";
  delete from "{% $schema %}"."{% $tables{namespaces} %}";
  delete from "{% $schema %}"."{% $tables{actions} %}";


=cut

sub schema_flush {
  my $c = shift;
  my $template = $c->_vars;
  $c->render(format=>'txt', text => <<TXT);

@{[$sql->{'flush'}->template(%$template)]}

TXT
}

1;

__DATA__


