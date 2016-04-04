package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin::Authentication';

our $VERSION = '0.130';

my $dbh;
my $admin;# 
my $pkg = __PACKAGE__;
my $conf ;# set on ->registrer


my $fail_auth = {format=>'txt', text=>"Deny at auth step. Please sign in!!!\n"};
my $fail_auth_cb = sub {shift->render(%$fail_auth);};
my $fail_access_cb = sub {shift->render(format=>'txt', text=>"You don`t have access on this action!!!\n");};



sub register {
  my ($self, $app,) = (shift, shift);
  $conf = shift; # global
  $dbh ||= $conf->{dbh} ||= $app->dbh;
  die "Plugin must work with arg dbh, see SYNOPSIS" unless $conf->{dbh};
  $conf->{admin} ||= {};
  $conf->{admin}{namespace} ||= $pkg unless $conf->{admin}{controller};
  $conf->{admin}{controller} ||= 'Admin';
  $conf->{admin}{prefix} ||= lc($conf->{controller});
  $conf->{admin}{trust} ||= $app->secrets->[0];
  $conf->{admin}{dbh} = $dbh;
  $conf->{admin}{fail_auth_cb} ||= $fail_auth_cb;
  $conf->{admin}{fail_access_cb} ||= $fail_access_cb;
  $admin ||= $self->admin_controller($app, $conf->{admin});
  
  $conf->{auth}{stash_key} ||= $pkg;
  $conf->{auth}{current_user_fn} ||= 'auth_user';
  $conf->{auth}{load_user} ||= \&load_user;
  $conf->{auth}{validate_user} ||= \&validate_user;
  $conf->{auth}{fail_render} ||= $fail_auth;
  $self->SUPER::register($app, $conf->{auth});
  
  $app->routes->add_condition(access => \&access);
  $admin->apply_route($app, $_) for @{ $admin->table_routes };
  
  if ($conf->{admin}{admin_routes}) {
    $admin->apply_route($app, $_) for $admin->admin_routes;
  }

}

sub admin_controller {# pseudo controller for auth, routes and access methods
  my ($self, $app, $conf) = @_;
  require ($conf->{namespace} =~ s/::/\//gr)."/$conf->{controller}.pm";# нельзя use!
  my $module = "$conf->{namespace}::$conf->{controller}";
  $module->import( qw(load_user validate_user) );
  return (bless $conf, $module)->init_class;
}


# 
sub access {# add_condition
  my ($route, $c, $captures, $r_item) = @_;
  # 1. по паролю выставить куки
  # 2. по кукам выставить пользователя
  my $meth = $conf->{auth}{current_user_fn};
  my $u = $c->$meth;
  # 3. если не проверять доступ вернуть 1
  return 1 unless $r_item->{auth};
  # не авторизовался
  $conf->{admin}{fail_auth_cb}->($c)
    and return undef
    unless $u;
  # 4. получить все группы пользователя
  $u->{roles} ||= $admin->load_user_roles($c, $u->{'id'});
  # 5. по ИДам групп и пользователя проверить доступ
  my $id2 = [$u->{id}, map($_->{id}, grep !$_->{disable},@{$u->{roles}})];
  ($r_item->{id} && $admin->access_route($c, $r_item->{id}, $id2))
    and $c->app->log->debug("Access on [$r_item->{namespace}::$r_item->{controller}->$r_item->{action}] for user id=[$u->{id}] by request=[$r_item->{request}]")
    and return 1;
  $admin->access_controller($c, $r_item, $id2)
    and $c->app->log->debug("Access all actions on $r_item->{namespace}::$r_item->{controller} for user id=$u->{id} by request=[$r_item->{request}]")
    and return 1;
  $conf->{admin}{fail_access_cb}->($c);
  #~ $c->app->log->debug($c->dumper($r_item));
  return undef;
}


1;



__END__

