package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin::Authentication';


our $VERSION = '0.02';

my $dbh;

my $load_user = sub {
  my ($c, $uid) = @_;
  $dbh->selectrow_hashref("select * from users where id = ?", undef, ($uid));
};

my $validate_user = sub {
  my ($c, $user, $pass, $extradata) = @_;
  scalar $dbh->selectrow_array("select id from users where login=? and pass=?", undef, ($user, $pass));
};

my $fail_render = {text=>"Access denied!!!"};

sub register {
  my ($self, $app, $args) = @_;
  $dbh = $args->{dbh} ||= $app->dbh;
  die "Plugin must work with arg dbh, see SYNOPSIS" unless $args->{dbh};
  $self->SUPER::register($app, {load_user=>$load_user, validate_user=> $validate_user, fail_render => $fail_render,},);
  my $r = $app->routes;
  $r->add_condition(__PACKAGE__ => \&_auth);
  my $sth = $dbh->prepare("select * from routes;");
  $sth->execute();
  while (my $r_item = $sth->fetchrow_hashref()) {
    next if $r_item->{disable};
    my @request = grep /\S/, split /\s+/, $r_item->{request};
    my $nr = $r->route(pop @request);
    $nr->via(@request) if @request;
    #~ $nr->over(__PACKAGE__ => $r_item);
    $nr->over(authenticated=>$r_item->{auth});
    $nr->to(controller=>$r_item->{controller}, action => $r_item->{action},);
    $nr->name($r_item->{name}) if $r_item->{name};
    #~ $app->log->debug("Generate route [@{[$app->dumper($nr)]}] from __PACKAGE__->register");
  }
  $sth->finish;
}


# 
sub _auth {
  my ($route, $c, $captures, $r_item) = @_;
  # 1. по паролю выставить куки
  # 2. по кукам выставить пользователя
  # 3. если не проверять доступ вернуть 1
  return 1 unless $r_item->{auth};
  # 4. получить все группы пользователя
  # 5. по ИДам групп и пользователя проверить доступ
  return 1; #ok
}

1;



__END__

