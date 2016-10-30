package Mojolicious::Plugin::RoutesAuthDBI::Schema;
use Mojo::Base 'Mojolicious::Controller';
use DBIx::Mojo::Template;

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
my $dict = DBIx::Mojo::Template->new(__PACKAGE__, vars=>$defaults, mt=>{tag_start=>'{%', tag_end=>'%}'});

=pod

=encoding utf8

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
@{[$dict->{'schema'}->template(%$template)]}

@{[$dict->{'sequence'}->template(%$template)]}

@{[$dict->{'routes'}->template(%$template)]}

@{[$dict->{'namespaces'}->template(%$template)]}

@{[$dict->{'controllers'}->template(%$template)]}

@{[$dict->{'actions'}->template(%$template)]}

@{[$dict->{profiles}->template(%$template)]}

@{[$dict->{'logins'}->template(%$template)]}

@{[$dict->{'roles'}->template(%$template)]}

@{[$dict->{'refs'}->template(%$template)]}

@{[$dict->{'oauth_sites'}->template(%$template)]}

@{[$dict->{'oauth_users'}->template(%$template)]}

TXT
}

sub schema_drop {
  my $c = shift;
  my $template = $c->_vars;
  #~ $schema = qq{"$schema".} if $schema;
  $c->render(format=>'txt', text => <<TXT);
@{[$dict->{'drop'}->template(%$template)]}

TXT
}

sub schema_flush {
  my $c = shift;
  my $template = $c->_vars;
  $c->render(format=>'txt', text => <<TXT);

@{[$dict->{'flush'}->template(%$template)]}

TXT
}

1;

__DATA__
@@ schema
%# Отдельная схема
CREATE SCHEMA IF NOT EXISTS "{%= $schema %}";
-- set search_path = "{%= $schema %}";

@@ sequence
%#  последовательность для всех

-- you may change schema name for PostgreSQL objects
CREATE SEQUENCE {%= $sequence %};-- one sequence for all tables id

@@ routes
-- маршруты
CREATE TABLE "{%= $schema %}"."{%= $tables->{routes} %}" (
  id integer default nextval('{%= $sequence %}'::regclass) not null primary key,
  ts timestamp without time zone default now() not null,
  request character varying not null,
  name character varying not null unique,
  descr text null,
  auth varchar null,
  -- was bit(1): alter table "{%= $schema %}"."{%= $tables->{routes} %}" alter column auth type varchar;
  disable bit(1) null,
  -- interval_ts - смещение ts (seconds) для приоритета маршрута, т.е. влияет на сортровку маршрутов
  interval_ts int null
  -- was order_by int null; alter table "{%= $schema %}"."{%= $tables->{routes} %}" rename column order_by to interval_ts;
);

@@ namespaces
-- спейсы
create table "{%= $schema %}"."{%= $tables->{namespaces} %}" (
  id integer default nextval('{%= $sequence %}'::regclass) not null primary key,
  ts timestamp without time zone default now() not null,
  namespace character varying not null unique,
  descr text null,
  -- alter table "{%= $schema %}"."{%= $tables->{namespaces} %}" add column app_ns bit(1) null;
  app_ns bit(1) null,
  -- interval_ts - смещение ts (seconds) для приоритета namespace
  interval_ts int null
  -- alter table "{%= $schema %}"."{%= $tables->{namespaces} %}" add column interval_ts int null;
);

@@ controllers
-- контроллеры
create table "{%= $schema %}"."{%= $tables->{controllers} %}" (
  id integer default nextval('{%= $sequence %}'::regclass) not null primary key,
  ts timestamp without time zone default now() not null,
  controller character varying not null,
  descr text null
);

@@ actions
-- действия
create table "{%= $schema %}"."{%= $tables->{actions} %}" (
  id integer default nextval('{%= $sequence %}'::regclass) not null primary key,
  ts timestamp without time zone default now() not null,
  action character varying not null,
  callback text null,
  descr text null
);

@@ logins
-- logins/pass table
create table "{%= $schema %}"."{%= $tables->{logins} %}" (
  id int default nextval('{%= $sequence %}'::regclass) not null  primary key,
  ts timestamp without time zone default now() not null,
  login varchar not null unique,
  pass varchar not null,
  disable bit(1)
);

@@ profiles
-- профили
create table "{%= $schema %}"."{%= $tables->{profiles} %}" (
  id int default nextval('{%= $sequence %}'::regclass) not null  primary key,
  ts timestamp without time zone default now() not null,
  names text[] not null,
  disable bit(1)
);

@@ roles
-- роли
create table "{%= $schema %}"."{%= $tables->{roles} %}" (
  id int default nextval('{%= $sequence %}'::regclass) not null  primary key,
  ts timestamp without time zone default now() not null,
  name varchar not null unique,
  disable bit(1)
);

@@ refs
-- Связи
create table "{%= $schema %}"."{%= $tables->{refs} %}" (
  id int default nextval('{%= $sequence %}'::regclass) not null  primary key,
  ts timestamp without time zone default now() not null,
  id1 int not null,
  id2 int not null,
  unique(id1, id2)
);
create index on "{%= $schema %}"."{%= $tables->{refs} %}" (id2);

@@ oauth_sites
-- Конфиг внешних сайтов, используемых в проекте
create table IF NOT EXISTS "{%= $schema %}"."{%= $tables->{oauth_sites} %}"  (
  id integer not null DEFAULT nextval('{%= $sequence %}'::regclass) primary key,-- sequence!
  name varchar not null unique,
  conf jsonb not null -- тут ключи приложений
);

@@ oauth_users
-- Oauth пользователи/профили
create table IF NOT EXISTS "{%= $schema %}"."{%= $tables->{oauth_users} %}" (
  id integer NOT NULL DEFAULT nextval('{%= $sequence %}'::regclass) primary key,
  ts timestamp without time zone NOT NULL DEFAULT now(),
  site_id int not null,
  user_id varchar not null, --
  profile jsonb,
  profile_ts timestamp without time zone NOT NULL DEFAULT now(),
  unique (site_id, user_id)
);

@@ drop
--drop table "{%= $schema %}"."{%= $tables->{refs} %}" cascade;
--drop table "{%= $schema %}"."{%= $tables->{logins} %}" cascade;
--drop table "{%= $schema %}"."{%= $tables->{profiles} %}" cascade;
--drop table "{%= $schema %}"."{%= $tables->{roles} %}" cascade;
--drop table "{%= $schema %}"."{%= $tables->{routes} %}" cascade;
--drop table "{%= $schema %}"."{%= $tables->{controllers} %}" cascade;
--drop table "{%= $schema %}"."{%= $tables->{actions} %}" cascade;
--drop table "{%= $schema %}"."{%= $tables->{namespaces} %}" cascade;
--drop table "{%= $schema %}"."{%= $tables->{oauth_sites} %}" cascade;
--drop table "{%= $schema %}"."{%= $tables->{oauth_users} %}" cascade;

drop schema "{%= $schema %}" cascade;
drop sequence {%= $sequence %};

@@ flush
delete from "{%= $schema %}"."{%= $tables->{refs} %}";
delete from "{%= $schema %}"."{%= $tables->{logins} %}";
delete from "{%= $schema %}"."{%= $tables->{profiles} %}";
delete from "{%= $schema %}"."{%= $tables->{roles} %}";
delete from "{%= $schema %}"."{%= $tables->{routes} %}";
delete from "{%= $schema %}"."{%= $tables->{controllers} %}";
delete from "{%= $schema %}"."{%= $tables->{namespaces} %}";
delete from "{%= $schema %}"."{%= $tables->{actions} %}";
delete from "{%= $schema %}"."{%= $tables->{oauth_sites} %}";
delete from "{%= $schema %}"."{%= $tables->{oauth_users} %}";

