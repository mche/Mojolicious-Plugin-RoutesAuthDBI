package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin::Authentication';
use Mojolicious::Plugin::RoutesAuthDBI::SQL;#  sth cache

our $VERSION = '0.08';

my $dbh;
#~ my $sth = {};
my $sth;# sth cache

my $pkg = __PACKAGE__;
my $conf ;# set on ->registrer

my $load_user = sub {
  my ($c, $uid) = @_;
  $c->app->log->debug("Loading user by id=$uid");
  $dbh->selectrow_hashref($sth->sth('user/id'), undef, ($uid));
};

my $validate_user = sub {
  my ($c, $login, $pass, $extradata) = @_;
  
  if (my $u = $dbh->selectrow_hashref($sth->sth('user/login'), undef, ($login))) {
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
  $dbh->selectall_arrayref($sth->sth('all routes'), { Slice => {} },);
  #~ $sth->execute();
  #~ $sth;
};


my $user_roles = sub {#load all roles of some user
  my ($c, $uid) = @_;
  $dbh->selectall_arrayref($sth->sth('user roles'), { Slice => {} }, ($uid));
};

my $ref = sub {#  check if ref between id1 and [IDs2] exists
  my ($c, $id1, $id2) = @_;
  return scalar $dbh->selectrow_array($sth->sth('cnt refs'), undef, ($id1, $id2));
  
};

my $fail_auth = {format=>'txt', text=>"Deny at auth step. Please sign in!!!"};

###########################END SQL SPECIFIC #####################################

sub register {
  my ($self, $app,) = (shift, shift);
  $conf = shift; # global
  $dbh ||= $conf->{dbh} ||= $app->dbh;
  #~ $sth = $conf->{sth}{$pkg} ||= {};
  die "Plugin must work with arg dbh, see SYNOPSIS" unless $conf->{dbh};
  $sth ||= bless [$dbh, {}], $pkg.'::SQL';
  $conf->{auth}{stash_key} ||= $pkg;
  $conf->{auth}{current_user_fn} ||= 'auth_user';
  $conf->{auth}{load_user} ||= $load_user;
  $conf->{auth}{validate_user} ||= $validate_user;
  $conf->{auth}{fail_render} ||= $fail_auth;
  $self->SUPER::register($app, $conf->{auth});
  
  $app->routes->add_condition(access => \&_access);
  $self->apply_routes($app, $db_routes->());
  $self->_admin_controller($app, $conf->{admin}) if $conf->{admin};
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
    #~ $nr->over(access => $r_item) if $r_item->{auth};
    
    $nr->to(controller=>$r_item->{controller}, action => $r_item->{action},  $r_item->{namespace} ? (namespace => $r_item->{namespace}) : (),);
    $nr->name($r_item->{name}) if $r_item->{name};
    $app->log->debug("$pkg generate the route from data row [@{[$app->dumper($r_item)]}]");
  }
  #~ $sth->finish;
}


sub _admin_controller {
  my ($self, $app, $conf) = @_;
  $conf->{trust} ||= $app->secrets->[0];
  $conf->{namespace} ||= $pkg;
  $conf->{prefix} ||= 'admin';
  my $r = $app->routes;
  require ($pkg =~ s/::/\//gr).'/Admin.pm';
  #~ my $c = ($pkg.'::Admin')->new;
  #~ require Mojolicious::Controller;
  my @r = (bless $conf, $pkg.'::Admin')->admin_routes();
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
  #~ my $r = $c->stash($conf->{auth}{stash_key})->{roles} ||= $user_roles->($c, $c->stash($conf->{auth}{stash_key})->{user}{id});
  my $meth = $conf->{auth}{current_user_fn};
  my $u = $c->$meth
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

