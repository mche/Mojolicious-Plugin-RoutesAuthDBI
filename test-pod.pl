use strict;
use utf8;
use Mojo::Util qw(dumper);
my $sql = Foo->instance(__FILE__);

print dumper(keys %$sql);


package Foo;
use utf8;
use base 'DBIx::POS';
#~ Foo->instance(__FILE__);


=encoding utf8

=name ывавп

=desc 1

=sql

  foo
  

=name foo

=desc

=sql

  foo

=cut
1;
__END__

use strict;
use utf8;
use Mojo::Util qw(dumper);
use Pod::Simple::PullParser;

my $parser = Pod::Simple::PullParser->new();

$parser->set_source( "lib/Mojolicious/Plugin/RoutesAuthDBI/Install.pm" );

while(my $token = $parser->get_token) {
  print $token->dump, "\n";
  
}