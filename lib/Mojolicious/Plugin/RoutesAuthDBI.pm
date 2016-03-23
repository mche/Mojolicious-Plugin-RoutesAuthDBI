package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin';


our $VERSION = '0.02';

my $dbh;

sub register {
  my ($plugin, $app, $args) = @_;
  $args ||= {};
  $dbh = $args->{dbh} ||= $app->dbh;
  die "Plugin must work with arg dbh, see SYNOPSIS" unless $args->{dbh};
  my $r = $app->routes;
  $r->add_condition(__PACKAGE__ => \&_auth);
  # $r->route(...)->over(__PACKAGE__=>$route_item)->... 
  my $sth = $dbh->prepare("select * from routes;");
  $sth->execute();
  while (my $r_item = $sth->fetchrow_hashref()) {
    next if $r_item->{disable};
    my @request = split /\s+/, $r_item->{request};
    $r->route(pop @request);
    $r->via(@request) if @request;
    $r->over(__PACKAGE__ => $r_item);
    $r->to(controller=>$r_item->{controller}, action => $r_item->{action},);
    $r->name($r_item->{name}) if $r_item->{name};
  }
  $sth->finish;
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

