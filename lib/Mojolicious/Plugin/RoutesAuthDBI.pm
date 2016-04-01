package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin::Authentication';
use Mojolicious::Plugin::RoutesAuthDBI::SQL;#  sth cache

our $VERSION = '0.08';

my $dbh;
#~ my $sth = {};
my $sql;# sth cache

my $pkg = __PACKAGE__;
my $conf ;# set on ->registrer

my $load_user = sub {
  my ($c, $uid) = @_;
  $c->app->log->debug("Loading user by id=$uid");
  $dbh->selectrow_hashref($sql->sth('user/id'), undef, ($uid));
};

my $validate_user = sub {
  my ($c, $login, $pass, $extradata) = @_;
  
  if (my $u = $dbh->selectrow_hashref($sql->sth('user/login'), undef, ($login))) {
    return $u->{id}
      if $u->{pass} eq $pass;
  } else {# auto sign UP
    #~ $c->app->log->debug("Register new user $login:$pass");
    #~ return scalar  $dbh->selectrow_array("insert into cubieusers (login, pass) values (?,?) returning id;", undef, ($login, $pass));
  }
  return undef;
};

my $db_routes = sub {$dbh->selectall_arrayref($sql->sth('all routes'), { Slice => {} },);};


my $user_roles = sub {#load all roles of some user
  my ($c, $uid) = @_;
  $dbh->selectall_arrayref($sql->sth('user roles'), { Slice => {} }, ($uid));
};

my $access_route = sub {#  check if ref between id1 and [IDs2] exists
  my ($id1, $id2) = @_;#id1 - the route, id2[] - user roles ids
  return scalar $dbh->selectrow_array($sql->sth('cnt refs'), undef, ($id1, $id2));
  
};

my $access_controller = sub {
  my ($r, $id2) = @_;
  return scalar $dbh->selectrow_array($sql->sth('access controller'), undef, ($r->{controller}, $r->{namespace},  $id2));
};

my $fail_auth = {format=>'txt', text=>"Deny at auth step. Please sign in!!!"};
my $fail_auth_cb = sub {shift->render(%$fail_auth);};
my $fail_access_cb = sub {shift->render(format=>'txt', text=>"You don`t have access on this action!!!");};


###########################END SQL SPECIFIC #####################################

sub register {
  my ($self, $app,) = (shift, shift);
  $conf = shift; # global
  $dbh ||= $conf->{dbh} ||= $app->dbh;
  #~ $sth = $conf->{sth}{$pkg} ||= {};
  die "Plugin must work with arg dbh, see SYNOPSIS" unless $conf->{dbh};
  $sql ||= bless [$dbh, {}], $pkg.'::SQL';
  $conf->{auth}{stash_key} ||= $pkg;
  $conf->{auth}{current_user_fn} ||= 'auth_user';
  $conf->{auth}{load_user} ||= $load_user;
  $conf->{auth}{validate_user} ||= $validate_user;
  $conf->{auth}{fail_render} ||= $fail_auth;
  $self->SUPER::register($app, $conf->{auth});
  
  $app->routes->add_condition(access => \&_access);
  $self->apply_route($app, $_) for @{$db_routes->()};
  
  $self->_admin_controller($app, $conf->{admin}) if $conf->{admin};
}


sub apply_route {
  my ($self, $app, $r_hash) = @_;
  my $r = $app->routes;
  return unless $r_hash->{request};
  my @request = grep /\S/, split /\s+/, $r_hash->{request}
    or return;
  my $nr = $r->route(pop @request);
  $nr->via(@request) if @request;
  
  # STEP AUTH не катит! только один over!
  #~ $nr->over(authenticated=>$r_hash->{auth});
  # STEP ACCESS
  $nr->over(access => $r_hash) if $r_hash->{auth};
  
  $nr->to(controller=>$r_hash->{controller}, action => $r_hash->{action},  $r_hash->{namespace} ? (namespace => $r_hash->{namespace}) : (),);
  $nr->name($r_hash->{name}) if $r_hash->{name};
  $app->log->debug("$pkg generate the route from data row [@{[$app->dumper($r_hash) =~ s/\n/ /gr]}]");
  return $nr;
}


sub _admin_controller {
  my ($self, $app, $conf) = @_;
  $conf->{trust} ||= $app->secrets->[0];
  $conf->{namespace} ||= $pkg;
  $conf->{prefix} ||= 'admin';
  #~ my $r = $app->routes;
  require ($pkg =~ s/::/\//gr).'/Admin.pm';
  $self->apply_route($app, $_) for (bless $conf, $pkg.'::Admin')->admin_routes();
  return;

  #~ my $ns = $r->namespaces;
  #~ push @$ns, grep !($_ ~~ $ns), __PACKAGE__;
  #~ push @{$app->renderer->paths}, Cwd::cwd().'/templates';
}


# 
sub _access {# add_condition
  my ($route, $c, $captures, $r_item) = @_;
  
  # 1. по паролю выставить куки
  # 2. по кукам выставить пользователя
  my $meth = $conf->{auth}{current_user_fn};
  my $u = $c->$meth;
  # 3. если не проверять доступ вернуть 1
  return 1 unless $r_item->{auth};
  # не авторизовался
  $fail_auth_cb->($c)
    and return undef
    unless $u;
  # 4. получить все группы пользователя
  $u->{roles} ||= $user_roles->($c, $u->{'id'});
  # 5. по ИДам групп и пользователя проверить доступ
  my $id2 = [$u->{id}, map($_->{id}, @{$u->{roles}})];
  ($r_item->{id} && $access_route->($r_item->{id}, $id2))
    and return 1;
  $access_controller->($r_item, $id2)
    and $c->app->log->debug("Access all actions on $r_item->{namespace}::$r_item->{controller} to user id=$u->{id}")
    and return 1;
  $fail_access_cb->($c);
  #~ $c->app->log->debug($c->dumper($r_item));
  return undef;
}

sub _roles {
  my ($c) = @_;
  
}

1;



__END__

