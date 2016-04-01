package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin::Authentication';

our $VERSION = '0.100';

my $dbh;
#~ my $sth = {};
my $admin;# 
my $pkg = __PACKAGE__;
my $conf ;# set on ->registrer

################################ SQL #####################################
sub load_user {
  my ($c, $uid) = @_;
  #~ $c->app->log->debug($c->dumper($c));
  my $u = $admin->get_user($uid);
  $c->app->log->debug("Loading user by id=$uid ".$u ? 'success' : 'failed');
  return $u;
}

sub validate_user {
  my ($c, $login, $pass, $extradata) = @_;
  $admin->validate_user($login, $pass, $extradata);
}

sub sql_routes {$admin->plugin_routes(@_)}


sub user_roles {#load all roles of some user
  my ($c, $uid) = @_;
  $admin->user_roles($uid);
}

sub access_route {#  check if ref between id1 and [IDs2] exists
  my $c = shift;#id1 - the route, id2[] - user roles ids
  $admin->access_route(@_);
}

sub access_controller {
  my $c = shift;
  $admin->access_controller(@_);
}

###########################END SQL SPECIFIC #################################

my $fail_auth = {format=>'txt', text=>"Deny at auth step. Please sign in!!!"};
sub fail_auth {shift->render(%$fail_auth);}
sub fail_access {shift->render(format=>'txt', text=>"You don`t have access on this action!!!");}



sub register {
  my ($self, $app,) = (shift, shift);
  $conf = shift; # global
  $dbh ||= $conf->{dbh} ||= $app->dbh;
  die "Plugin must work with arg dbh, see SYNOPSIS" unless $conf->{dbh};
  $admin ||= $self->_admin_controller($app, $conf->{admin} || {});
  $conf->{auth}{stash_key} ||= $pkg;
  $conf->{auth}{current_user_fn} ||= 'auth_user';
  $conf->{auth}{load_user} ||= \&load_user;
  $conf->{auth}{validate_user} ||= \&validate_user;
  $conf->{auth}{fail_render} ||= $fail_auth;
  $self->SUPER::register($app, $conf->{auth});
  
  $app->routes->add_condition(access => \&_access);
  $self->apply_route($app, $_) for @{sql_routes()};
  
  if ($conf->{admin}) {
    $self->apply_route($app, $_) for $admin->admin_routes();
  }

}


sub _admin_controller {
  my ($self, $app, $conf) = @_;
  $conf->{trust} ||= $app->secrets->[0];
  $conf->{namespace} ||= $pkg;
  $conf->{prefix} ||= 'admin';
  $conf->{dbh} ||= $dbh;
  require ($pkg =~ s/::/\//gr).'/Admin.pm';# нельзя use!
  return (bless $conf, $pkg.'::Admin')->init;
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
  fail_auth($c)
    and return undef
    unless $u;
  # 4. получить все группы пользователя
  $u->{roles} ||= user_roles($c, $u->{'id'});
  # 5. по ИДам групп и пользователя проверить доступ
  my $id2 = [$u->{id}, map($_->{id}, @{$u->{roles}})];
  ($r_item->{id} && access_route($c, $r_item->{id}, $id2))
    and return 1;
  access_controller($c, $r_item, $id2)
    and $c->app->log->debug("Access all actions on $r_item->{namespace}::$r_item->{controller} to user id=$u->{id}")
    and return 1;
  fail_access($c);
  #~ $c->app->log->debug($c->dumper($r_item));
  return undef;
}


1;



__END__

