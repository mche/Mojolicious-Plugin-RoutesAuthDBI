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
  
  
  
};

sub sth {
  my ($dbh, $st) = @{ shift() };
  my $id = shift;
  $sth ||= $st; # init cache
  $sth->{$id} ||= $dbh->prepare($sql->{$id});
}