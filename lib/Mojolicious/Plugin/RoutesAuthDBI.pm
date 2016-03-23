package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin';


our $VERSION = '0.02';

sub register {
  my ($plugin, $app, @args) = @_;
  my $r = $app->routes;
}

1;

__END__

