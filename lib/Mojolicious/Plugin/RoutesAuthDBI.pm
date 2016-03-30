package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin::Authentication';


our $VERSION = '0.07';

my $dbh;
my $sth;
my $pkg = __PACKAGE__;
my $args = {};# set on ->registrer

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
    #~ $c->app->log->debug("Register new user $login:$pass");
    #~ return scalar  $dbh->selectrow_array("insert into cubieusers (login, pass) values (?,?) returning id;", undef, ($login, $pass));
  }
  return undef;
};

my $db_routes = sub {
  #~ my $sth = 
  $dbh->selectall_arrayref("select * from routes where coalesce(disable, 0::bit) <> 1::bit order by order_by, ts;", { Slice => {} },);
  #~ $sth->execute();
  #~ $sth;
};


my $user_roles = sub {#load all roles of some user
  my ($c, $uid) = @_;
  $dbh->selectall_arrayref("select g.* from roles g join refs r on g.id=r.id1 where r.id2=?", { Slice => {} }, ($uid));
};

my $ref = sub {#  check if ref between id1 and [IDs2] exists
  my ($c, $id1, $id2) = @_;
  return scalar $dbh->selectrow_array("select count(*) from refs where id1 = ? and id2 = ANY(?)", undef, ($id1, $id2));
  
};

my $fail_auth = {format=>'txt', text=>"Deny at auth step. Please sign in!!!"};

###########################END OF OPTIONS #####################################

sub register {
  my ($self, $app,) = (shift, shift);
  $args = shift; # global
  $dbh = $args->{dbh} ||= $app->dbh;
  $sth = $args->{sth}{$pkg} ||= {};
  die "Plugin must work with arg dbh, see SYNOPSIS" unless $args->{dbh};
  $args->{auth}{stash_key} ||= $pkg;
  $self->SUPER::register($app, {load_user=>$load_user, validate_user=> $validate_user, fail_render => $fail_auth, %{$args->{auth} || {}}, },);
  $app->routes->add_condition(access => \&_access);
  $self->apply_routes($app, $db_routes->());
  $self->_admin_controller($app, $args->{admin}) if $args->{admin};
}


sub apply_routes {
  my ($self, $app, $rs) = @_;
  return unless $rs && @$rs;
  my $r = $app->routes;
  while (my $r_item = shift @$rs) {
  #~ my $sth = $sth_routes->();
  #~ while (my $r_item = $sth->fetchrow_hashref()) {
    #~ next if $r_item->{disable};
    my @request = grep /\S/, split /\s+/, $r_item->{request}
      or next;
    my $nr = $r->route(pop @request);
    $nr->via(@request) if @request;
    
    # STEP AUTH
    $nr->over(authenticated=>$r_item->{auth});
    # STEP ACCESS
    $nr->over(access => $r_item) if $r_item->{auth};
    
    $nr->to(controller=>$r_item->{controller}, action => $r_item->{action},  $r_item->{namespace} ? (namespace => $r_item->{namespace}) : (),);
    $nr->name($r_item->{name}) if $r_item->{name};
    $app->log->debug("$pkg generate the route from data row [@{[$app->dumper($r_item)]}]");
  }
  #~ $sth->finish;
}


sub _admin_controller {
  my ($self, $app, $conf) = @_;
  my $r = $app->routes;
  require ($pkg =~ s/::/\//gr).'/Admin.pm';
  #~ my $c = ($pkg.'::Admin')->new;
  #~ require Mojolicious::Controller;
  my @r = (bless {}, $pkg.'::Admin')->admin_routes($conf->{prefix}, $conf->{trust} && $app->secrets->[0]);
  $self->apply_routes($app, \@r);
  return;

  #~ my $ns = $r->namespaces;
  #~ push @$ns, grep !($_ ~~ $ns), __PACKAGE__;
  #~ push @{$app->renderer->paths}, Cwd::cwd().'/templates';
}


# 
sub _access {# add_condition
  my ($route, $c, $captures, $r_item) = @_;
  return 1 unless $r_item->{auth};
  #~ $c->app->log->debug($c->dumper($route));
  # 1. по паролю выставить куки
  # 2. по кукам выставить пользователя
  # 3. если не проверять доступ вернуть 1
  #~ return 1 unless $r_item->{auth};
  # 4. получить все группы пользователя
  #~ my $r = $c->stash($args->{auth}{stash_key})->{roles} ||= $user_roles->($c, $c->stash($args->{auth}{stash_key})->{user}{id});
  my $u = $c->auth_user
    or return undef;
  $u->{roles} ||= $user_roles->($c, $u->{'id'});
  #~ $c->app->log->debug($c->dumper($c->auth_user));
  # 5. по ИДам групп и пользователя проверить доступ
  #~ return undef;
  return 1; #ok
}

sub _roles {
  my ($c) = @_;
  
}

1;



__END__

