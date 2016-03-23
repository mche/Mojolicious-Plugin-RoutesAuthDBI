package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin';


our $VERSION = '0.02';

sub register {
  my ($plugin, $app, @args) = @_;
  my $r = $app->routes;
  $r->add_condition(__PACKAGE__ => \&_auth);
  # $r->route(...)->over(__PACKAGE__)->... if auth column of sql route record is true
}

# 
sub _auth {
  my ($route, $c, $captures, $patterns) = @_;
  
}

1;



__END__

