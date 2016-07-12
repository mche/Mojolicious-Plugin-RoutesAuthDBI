package Mojolicious::Plugin::RoutesAuthDBI::Schema;
use Mojo::Base 'Mojolicious::Controller';
use DBIx::POS::Template;

our $defaults = {# copy to pod!
  schema => "public",
  sequence => '"public"."id"',
  tables => { # no quotes! one schema!
    routes => 'routes',
    refs=>'refs',
    logins => 'logins',
    profiles => 'profiles',
    roles =>'roles',
    actions => 'actions',
    controllers => 'controllers',
    namespaces => 'namespaces',
    oauth_sites => 'oauth.sites',
    oauth_users => 'oauth.users',
  },
  
};
my $pos = DBIx::POS::Template->new(__FILE__, template=>$defaults,);

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

=head2 Default variables for SQL templates

  {
  schema => "public",
  sequence => '"public"."id"',
  tables => { # no quotes! one schema!
    routes => 'routes',
    refs=>'refs',
    logins => 'logins',
    profiles => 'profiles',
    roles =>'roles',
    actions => 'actions',
    controllers => 'controllers',
    namespaces => 'namespaces',
    oauth_sites => 'oauth.sites',
    oauth_users => 'oauth.users',
    },
  }

=head2 Schema

=name schema

=desc Отдельная схема

=sql

  
  CREATE SCHEMA IF NOT EXISTS "{% $schema %}";
  -- set search_path = "{% $schema %}";

=head2 Sequence

=name sequence

=desc последовательность для всех

=sql

  -- you may change schema name for PostgreSQL objects
  
  CREATE SEQUENCE {% $sequence %};-- one sequence for all tables id

=head2 Routes table

=name routes

=desc маршруты

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

=desc спейсы

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

=desc контроллеры

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

=head2 Logins table

=name logins

=desc

Its logins table

=sql

  create table "{% $schema %}"."{% $tables{logins} %}" (
    id int default nextval('{% $sequence %}'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    login varchar not null unique,
    pass varchar not null,
    disable bit(1)
  );

=head2 Profiles table

=name profiles

=desc профили

=sql

  create table "{% $schema %}"."{% $tables{profiles} %}" (
    id int default nextval('{% $sequence %}'::regclass) not null  primary key,
    ts timestamp without time zone default now() not null,
    names text[] not null,
    disable bit(1)
  );

=head2 Roles table

=name roles

=desc роли

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

=head2 Oauth sites

=name oauth_sites

=desc

Конфиг внешних сайтов, используемых в проекте

=sql

  create table IF NOT EXISTS "{% $schema %}"."{% $tables{oauth_sites} %}"  (
    id integer not null DEFAULT nextval('{% $sequence %}'::regclass) primary key,-- sequence!
    name varchar not null unique,
    conf jsonb not null -- тут ключи приложений
  );

=head2 Oauth users

=name oauth_users

=desc

Oauth пользователи

=sql

  create table IF NOT EXISTS "{% $schema %}"."{% $tables{oauth_users} %}" (
    id integer NOT NULL DEFAULT nextval('{% $sequence %}'::regclass) primary key,
    ts timestamp without time zone NOT NULL DEFAULT now(),
    site_id int not null,
    user_id varchar not null, --
    profile jsonb,
    profile_ts timestamp without time zone NOT NULL DEFAULT now(),
    unique (site_id, user_id)
  );

=cut


sub _vars {
  my $c = shift;
  my $template = {};

  for my $var (keys %$defaults) {
    my $val = $c->stash($var) || $c->param($var);
    $template->{$var} = $val
      and next
      if $val;
      
    $template->{$var} = { map {
      my $val = $c->stash($_) || $c->param($_);
      $val ? ($_ => $val) : ();
    
    } keys %{$defaults->{$var}}  }
      if ref $defaults->{$var};
  }
  $template;
}

sub schema {
  my $c = shift;
  my $template = $c->_vars;
  
  $c->app->log->debug($c->dumper($template));
  
  #~ my $schema2 = qq{"$schema".} if $schema;
  $c->render(format=>'txt', text => <<TXT);
@{[$pos->{'schema'}->template(%$template)]}

@{[$pos->{'sequence'}->template(%$template)]}

@{[$pos->{'routes'}->template(%$template)]}

@{[$pos->{'namespaces'}->template(%$template)]}

@{[$pos->{'controllers'}->template(%$template)]}

@{[$pos->{'actions'}->template(%$template)]}

@{[$pos->{profiles}->template(%$template)]}

@{[$pos->{'logins'}->template(%$template)]}

@{[$pos->{'roles'}->template(%$template)]}

@{[$pos->{'refs'}->template(%$template)]}

@{[$pos->{'oauth_sites'}->template(%$template)]}

@{[$pos->{'oauth_users'}->template(%$template)]}

TXT
}

=pod

=head1 Drop

=name drop

=desc

=sql

  drop table "{% $schema %}"."{% $tables{refs} %}";
  drop table "{% $schema %}"."{% $tables{logins} %}";
  drop table "{% $schema %}"."{% $tables{profiles} %}";
  drop table "{% $schema %}"."{% $tables{roles} %}";
  drop table "{% $schema %}"."{% $tables{routes} %}";
  drop table "{% $schema %}"."{% $tables{controllers} %}";
  drop table "{% $schema %}"."{% $tables{actions} %}";
  drop table "{% $schema %}"."{% $tables{namespaces} %}";
  drop table "{% $schema %}"."{% $tables{oauth_sites} %}";
  drop table "{% $schema %}"."{% $tables{oauth_users} %}";
  drop sequence {% $sequence %};


=cut

sub schema_drop {
  my $c = shift;
  my $template = $c->_vars;
  #~ $schema = qq{"$schema".} if $schema;
  $c->render(format=>'txt', text => <<TXT);
@{[$pos->{'drop'}->template(%$template)]}

TXT
}

=pod

=head1 Flush

=name flush

=desc

=sql

  delete from "{% $schema %}"."{% $tables{refs} %}";
  delete from "{% $schema %}"."{% $tables{logins} %}";
  delete from "{% $schema %}"."{% $tables{profiles} %}";
  delete from "{% $schema %}"."{% $tables{roles} %}";
  delete from "{% $schema %}"."{% $tables{routes} %}";
  delete from "{% $schema %}"."{% $tables{controllers} %}";
  delete from "{% $schema %}"."{% $tables{namespaces} %}";
  delete from "{% $schema %}"."{% $tables{actions} %}";
  delete from "{% $schema %}"."{% $tables{oauth_sites} %}";
  delete from "{% $schema %}"."{% $tables{oauth_users} %}";


=cut

sub schema_flush {
  my $c = shift;
  my $template = $c->_vars;
  $c->render(format=>'txt', text => <<TXT);

@{[$pos->{'flush'}->template(%$template)]}

TXT
}

1;

__DATA__


