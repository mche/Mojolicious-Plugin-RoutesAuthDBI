package Test::Test;
#Mojolicious::Plugin::RoutesAuthDBI::
use Mojo::Base 'Mojolicious::Controller';

my $pkg = __PACKAGE__;

sub test1 {
  my $c = shift;
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

test1.....................ok

TXT
  
}


1;