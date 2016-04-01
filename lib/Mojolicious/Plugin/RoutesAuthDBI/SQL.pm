package Mojolicious::Plugin::RoutesAuthDBI::SQL;
use Mojo::Base -strict;

=pod
my $a = {};
print ($a, (bless $a, 'Foo')->a, "\n");
print "hop\n";
$a = {};
print ($a, (bless $a, 'Foo')->a, "\n");

exit;

package Foo;

print "init Foo!\n";
my $a = 1;

sub a {(shift, ++$a);} 
1;
=cut

my $sth;
my $sql = {
  'user/id'=>"select * from users where id = ?",# Plugin load_user by id
  'user/login'=>"select * from users where login=?",
  'all routes'=> "select * from routes where coalesce(disable, 0::bit) <> 1::bit order by order_by, ts;",
  'user roles'=> "select g.* from roles g join refs r on g.id=r.id1 where r.id2=?",
  'cnt refs' => "select count(*) from refs where id1 = ? and id2 = ANY(?)",#  check if ref between id1 and [IDs2] exists
  'access controller'=>"select count(r.*) from routes r join refs s on r.id=s.id1 where lower(r.controller)=lower(?) and r.namespace=? and r.request is null and r.action is null and s.id2=any(?);",# доступ ко всем действиям по имени контроллера
  
  
};

sub new {
  my ($class, $dbh, $st) = @_;
  $sth ||= $st ||= {};
  bless([$dbh, $sth], $class);
}

sub sth {
  my ($dbh, $st) = @{ shift() };
  my $key = shift;
  $sth ||= $st; # init cache
  return $sth unless $key;
  $sth->{$key} ||= $dbh->prepare($sql->{$key});
}