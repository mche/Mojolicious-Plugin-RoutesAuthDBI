package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin::Authentication';


our $VERSION = '0.05';

my $dbh;

my $load_user = sub {
  my ($c, $uid) = @_;
  $c->app->log->debug("Loading user by id=$uid");
  $dbh->selectrow_hashref("select * from users where id = ?", undef, ($uid));
};

my $validate_user = sub {
  my ($c, $login, $pass, $extradata) = @_;
  
  if (my $u = $dbh->selectrow_hashref("select * from users where login=?", undef, ($login))) {
    return $u->{id}
      if $u->{pass} eq $pass;
  } else {# auto sign UP
    $c->app->log->debug("Register new user $login:$pass");
    return scalar  $dbh->selectrow_array("insert into users (login, pass) values (?,?) returning id;", undef, ($login, $pass));
  }
  return undef;
};

my $sth_routes = sub {
  my $sth = $dbh->prepare("select * from routes where coalesce(disable, 0::bit) <> 1::bit;");
  $sth->execute();
  $sth;
};


my $user_roles = sub {#load all roles of some user
  my ($c, $uid) = @_;
  $dbh->selectall_hashref("select g.* from roles g join refs r on g.id=r.id1 where r.id2=?", undef, ($uid));
};

my $ref = sub {#  check if ref between id1 and [IDs2] exists
  my ($c, $id1, $id2) = @_;
  return scalar $dbh->selectrow_array("select count(*) from refs where id1 = ? and id2 = ANY(?)", undef, ($id1, $id2));
  
};

my $fail_render = {format=>'txt', text=>"Deny at auth step. Please sign in/up at /sign/<login>/<pass>!!!"};

###########################END OF OPTIONS #####################################

sub register {
  my ($self, $app, $args) = @_;
  $dbh = $args->{dbh} ||= $app->dbh;
  die "Plugin must work with arg dbh, see SYNOPSIS" unless $args->{dbh};
  $self->SUPER::register($app, {load_user=>$load_user, validate_user=> $validate_user, fail_render => $fail_render, %{$args->{auth} || {}}, },);
  $self->generate_routes($app);

}


sub generate_routes {
  my ($self, $app,) = @_;
  my $r = $app->routes;
  $r->add_condition(__PACKAGE__ => \&_auth);
  my $sth = $sth_routes->();
  while (my $r_item = $sth->fetchrow_hashref()) {
    #~ next if $r_item->{disable};
    my @request = grep /\S/, split /\s+/, $r_item->{request};
    my $nr = $r->route(pop @request);
    $nr->via(@request) if @request;
    #~ $nr->over(__PACKAGE__ => $r_item);
    $nr->over(authenticated=>$r_item->{auth});
    $nr->to(controller=>$r_item->{controller}, action => $r_item->{action},);
    $nr->name($r_item->{name}) if $r_item->{name};
    $app->log->debug(__PACKAGE__." generate the route [@{[$app->dumper($r_item)]}]");
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

