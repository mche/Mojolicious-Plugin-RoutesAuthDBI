package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin';


our $VERSION = '0.02';

sub register {
  my ($plugin, $app, $args) = @_;
  $args ||= {};
  $args->{dbh} ||= $app->dbh;
  die "Plugin must work with arg dbh, see SYNOPSIS" unless $args->{dbh};
  my $r = $app->routes;
  $r->add_condition(__PACKAGE__ => \&_auth);
  # $r->route(...)->over(__PACKAGE__=>$route_item)->... 
}

# 
sub _auth {
  my ($route, $c, $captures, $route) = @_;
  # 1. по паролю выставить куки
  # 2. по кукам выставить пользователя
  # 3. если не проверять доступ вернуть 1
  # 4. получить все группы пользователя
  # 5. по ИДам групп и пользователя проверить доступ
  return 1; #ok
}

1;



__END__

