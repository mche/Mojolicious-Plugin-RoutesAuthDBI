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

=cut

my $dbh;
my $sth;
my $sql = {
  'user/id'=>"select * from users where id = ? and coalesce(disable, 0::bit) <> 1::bit",# Plugin load_user by id
  'user/login'=>"select * from users where login=?",
  'user'=>"select * from users where id = ? or login=?",
  'all routes'=> "select * from routes order by order_by, ts;",
  'user roles enbl'=> "select g.* from roles g join refs r on g.id=r.id1 where r.id2=? and coalesce(g.disable, 0::bit) <> 1::bit",
  'cnt refs' => "select count(*) from refs where id1 = ? and id2 = ANY(?)",#  check if ref between id1 and [IDs2] exists
  'access controller'=>"select count(r.*) from routes r join refs s on r.id=s.id1 where lower(r.controller)=lower(?) and r.namespace=? and r.request is null and r.action is null and s.id2=any(?) and coalesce(r.disable, 0::bit) <> 1::bit;",# доступ ко всем действиям по имени контроллера
  
  'new_user'=> "insert into users (login, pass) values (?,?) returning *;",
  #~ 'role/name'=>"select * from roles where lower(name)=?",
  'role'=>"select * from roles where id=? or lower(name)=?",
  'new_role'=>"insert into roles (name) values (?) returning *;",
  
  'ref'=>"select * from refs where id1=? and id2=?;",
  'new_ref'=>"insert into refs (id1,id2) values (?,?) returning *;",
  
  'route/controller'=>"select * from routes where namespace=? and lower(controller)=? and request is null and action is null",
  'new_route'=>"insert into routes (request, name, namespace, controller, action, auth, descr, disable, order_by) values (?,?,?,?,?,?,?,?,?) returning *;",
  
  'role_users'=>"select u.* from users u join refs r on u.id=r.id2 where r.id1=?",
  'role_routes'=> "select t.* from routes t join refs r on t.id=r.id1 where r.id2=?",
  
  
  
};

sub new {
  my ($class, $db, $st) = @_;
  $dbh ||= $db or die "Not defined dbh DBI handle";
  $sth ||= $st ||= {};
  bless([$dbh, $sth], $class);
}

sub sth {
  my ($db, $st) = @{ shift() };
  my $key = shift;
  $dbh ||= $db or die "Not defined dbh DBI handle"; # init dbh once
  $sth ||= $st; # init cache once
  return $sth unless $key;
  $sth->{$key} ||= $dbh->prepare($sql->{$key});
}