package Mojolicious::Plugin::RoutesAuthDBI::PgSQL;
use Mojo::Base -strict;

=pod

=encoding utf8

=head NAME

Mojolicious::Plugin::RoutesAuthDBI::PgSQL - is a SQL hub for L<Mojolicious::Plugin::RoutesAuthDBI::Admin>.

=head1 SYNOPSIS

    my $sql = bless [$dbh, {}], 'Mojolicious::Plugin::RoutesAuthDBI::PgSQL';
    my $r = $dbh->selectrow_hashref($sql->sth('foo key'));

=head1 DESCRIPTION

A whole class DBI statement cache.

=head1 SQL schema

    Refs between three tables in order: route -> role -> user

=over 4

=item * Pg sequence for column id on all tables

    create sequence ID;

=item * Table of routes

    create table routes(
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

=item * Table of users

    create table users(
        id int default nextval('ID'::regclass) not null  primary key,
        ts timestamp without time zone default now() not null,
        login varchar not null unique,
        pass varchar not null
    );

=item * Table of users roles

    create table roles(
        id int default nextval('ID'::regclass) not null  primary key,
        ts timestamp without time zone default now() not null,
        name varchar not null unique
    );

=item * Table of references between routes, users and roles

    create table refs(
        id int default nextval('ID'::regclass) not null  primary key,
        ts timestamp without time zone default now() not null,
        id1 int not null,
        id2 int not null,
        unique(id1, id2)
    );
    create index on refs (id2);

where:
	id1 - primary id of reference,
	id2 - secondary id of reference


=back

=cut

my $dbh;
my $sth;
my $sql = {
  'user/id'=>"select * from users where id = ? and coalesce(disable, 0::bit) <> 1::bit",# Plugin load_user by id
  'user/login'=>"select * from users where login=?",
  'user'=>"select * from users where id = ? or login=?",
  'all routes'=> "select * from routes order by order_by, ts;",
  'user roles'=> "select g.* from roles g join refs r on g.id=r.id1 where r.id2=?",# and coalesce(g.disable, 0::bit) <> 1::bit
  'cnt refs' => "select count(*) from refs where id1 = ? and id2 = ANY(?)",#  check if ref between id1 and [IDs2] exists
  'access controller'=>"select count(r.*) from routes r join refs s on r.id=s.id1 where lower(r.controller)=lower(?) and r.namespace=? and r.request is null and r.action is null and s.id2=any(?) and coalesce(r.disable, 0::bit) <> 1::bit;",# доступ ко всем действиям по имени контроллера
  
  'new_user'=> "insert into users (login, pass) values (?,?) returning *;",
  #~ 'role/name'=>"select * from roles where lower(name)=?",
  'role'=>"select * from roles where id=? or lower(name)=?",
  'new_role'=>"insert into roles (name) values (?) returning *;",
  'dsbl/enbl role'=>"update roles set disable=?::bit where id=? or lower(name)=? returning *;",
  
  'ref'=>"select * from refs where id1=? and id2=?;",
  'new_ref'=>"insert into refs (id1,id2) values (?,?) returning *;",
  'del ref'=>"delete from refs where id1=? and id2=? returning *;",
  
  'route/controller'=>"select * from routes where namespace=? and lower(controller)=? and request is null and action is null",
  'new_route'=>"insert into routes (request, name, namespace, controller, action, auth, descr, disable, order_by) values (?,?,?,?,?,?,?,?,?) returning *;",
  
  'role_users'=>"select u.* from users u join refs r on u.id=r.id2 where r.id1=?",
  'role_routes'=> "select t.* from routes t join refs r on t.id=r.id1 where r.id2=?",
  
  
  
};

#~ sub new {
  #~ my ($class, $db, $st) = @_;
  #~ $dbh ||= $db or die "Not defined dbh DBI handle";
  #~ $sth ||= $st ||= {};
  #~ bless([$dbh, $sth], $class);
#~ }

sub sth {
  my ($db, $st) = @{ shift() };
  my $key = shift;
  $dbh ||= $db or die "Not defined dbh DBI handle"; # init dbh once
  $sth ||= $st; # init cache once
  return $sth unless $key;
  die "No such key[$key] on SQL!" unless $sql->{$key};
  $sth->{$key} ||= $dbh->prepare($sql->{$key});
}