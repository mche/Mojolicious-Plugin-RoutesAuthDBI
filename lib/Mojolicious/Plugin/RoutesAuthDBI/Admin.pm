package Mojolicious::Plugin::RoutesAuthDBI::Admin;
use Mojo::Base 'Mojolicious::Controller';
use Mojolicious::Plugin::RoutesAuthDBI::PgSQL;#  sth cache

my $dbh; # one per class
my $pkg = __PACKAGE__;
my $init_conf;
my $sql;#sth hub

=pod
=encoding utf8

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Admin - is a mixed Mojolicious::Controller. It invoking from plugin module and might also using as standard Mojolicious::Controller. From plugin it controll access to routes trought sintax of ->over(...), see L<Mojolicious::Routes::Route#over>

=head1 SYNOPSIS

    $app->plugin('RoutesAuthDBI', 
        dbh => $app->dbh,
        auth => {...},
        access => {...},
        admin => {< options below >},
    );


=over 4

=item * B<namespace> - default 'Mojolicious::Plugin::RoutesAuthDBI',

=item * B<controller> - module controller name, default 'Admin',

Both above options determining the module controller for web actions on tables routes, roles, users and refs between them.

=item * B<prefix> -is a prefix for admin urls of this module. Default as name of controller lowcase.

=item * B<trust> is a url subprefix for trust admin urls of this module. See defaults below.

=back

=head2 Defaults

    admin = > {
        namespace => 'Mojolicious::Plugin::RoutesAuthDBI',
        module => 'Admin',
        prefix => 'admin',
        trust => $app->secrets->[0],
    },
    
    admin = {}, # empty hashref sets defaults above
    
    admin => undef, # disables routing of admin controller
    
    admin = > {prefix=>'myadmin', trust => 'foooobaaar'},# admin urls like: /myadmin/foooobaaar/.....



head1 METHODS NEEDS IN PLUGIN

=over 4

=item * B<self_routes()> - builtin this access controller routes. Return array of hashrefs. Depends on conf options I<prefix> and I<trust>.

=back

=cut

sub init_class {# from plugin! init Class vars
	my $c = shift;
	my $args = {@_};
  $init_conf ||= $c;
  $c->{prefix} =~ s/^\///;
  $c->{trust} =~ s/\W/-/g;
	$c->{dbh} ||= $dbh ||=  $args->{dbh};
	$dbh ||= $c->{dbh};
	$c->{sql} ||= $sql ||= $args->{sql} ||= bless [$dbh, {}], $c->{namespace}.'::PgSQL';#sth cache
	$sql ||= $c->{sql};
    
	return $c;
}


sub index {
  my $c = shift;
  
  $c->app->log->debug($c->dumper( $c->auth_user));
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

You are signed as:
@{[$c->dumper( $c->auth_user)]}


@{[map "$_->{request}\t\t$_->{descr}\n", $c->self_routes]}

TXT
    and return
    if $c->is_user_authenticated;
  
  $c->render(format=>'txt', text=>__PACKAGE__."\n\nYou are not signed!!! To sign in/up go to /sign/<login>/<pass>");
}

sub sign {
  my $c = shift;
  
  $c->authenticate($c->stash('login') || $c->param('login'), $c->stash('pass') || $c->param('pass'))
    and $c->render(format=>'txt', text=>__PACKAGE__ . "\n\nSuccessfull signed! ".$c->dumper( $c->auth_user))
    and return;
    
  
  $c->render(format=>'txt', text=>__PACKAGE__ . "\n\nBad sign!!! Try again");
}

sub signout {
  my $c = shift;
  
  $c->logout;
  
  $c->render(format=>'txt', text=>__PACKAGE__ . "\n\nYou are exited!!!");
  
}

sub new_user {
  my $c = shift;
  
  my ($login, $pass) = ($c->stash('login') || $c->param('login'), $c->stash('pass') ||  $c->param('pass'));
  
  my $r;
  ($r = $dbh->selectrow_hashref($sql->sth('user/login'), undef, ($login)))
    and $c->render(format=>'txt', text=><<TXT)
$pkg

User already exists!

@{[$c->dumper( $r)]}
TXT
    and ($r->{not_new} = '!')
    and return $r;
  
  $r = $dbh->selectrow_hashref($sql->sth('new_user'), undef, ($login, $pass));
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

Success sign up new user!

@{[$c->dumper( $r)]}
TXT
  return $r;
}

sub trust_new_user {
  my $c = shift;
  
  my $u = $c->new_user;
  #~ return if $u->{not_new};
  
  # ROLE
  my $rl = $dbh->selectrow_hashref($sql->sth('role'), undef, (undef, 'admin'));
  $rl ||= $dbh->selectrow_hashref($sql->sth('new_role'), undef, ('admin'));
  
  # REF role->user
  my $ru = $dbh->selectrow_hashref($sql->sth('ref'), undef, ($rl->{id}, $u->{id}));
  $ru ||= $dbh->selectrow_hashref($sql->sth('new_ref'), undef, ($rl->{id}, $u->{id}));
  
  # ROUTE
  my $rt = $dbh->selectrow_hashref($sql->sth('route/controller'), undef, ($init_conf->{namespace}, $init_conf->{controller}));
  $rt ||= $dbh->selectrow_hashref($sql->sth('new_route'), undef, (undef, 'admin controller', $init_conf->{namespace}, $init_conf->{controller}, undef, 1, "Access to all $init_conf->{namespace}\::$init_conf->{controller} actions", undef, undef,));
    
    #REF route->role
  my $rr = $dbh->selectrow_hashref($sql->sth('ref'), undef, ($rt->{id}, $rl->{id}));
  $rr ||= $dbh->selectrow_hashref($sql->sth('new_ref'), undef, ($rt->{id}, $rl->{id}));
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

Success sign up new trust-user!

USER:
@{[$c->dumper( $u)]}

ROLE:
@{[$c->dumper( $rl)]}

ROUTE:
@{[$c->dumper( $rt)]}

TXT
}

sub new_role {
	my $c = shift;
	my $name = $c->stash('name');
	my $r = $dbh->selectrow_hashref($sql->sth('role'), undef, (undef, $name));
	$c->render(format=>'txt', text=><<TXT)
$pkg

Exists role!

@{[$c->dumper( $r)]}

TXT
		and return $c
		if $r;
	$r = $dbh->selectrow_hashref($sql->sth('new_role'), undef, ($name));
	
	$c->render(format=>'txt', text=><<TXT);
$pkg

Success created role!

@{[$c->dumper( $r)]}

TXT
	
}

sub user_roles {
  my $c = shift;
  my $user = $c->stash('user') || $c->param('user');
  my $u =  $dbh->selectrow_hashref($sql->sth('user'), undef, ($user =~ /\D/ ? (undef, $user) : ($user, undef,)));
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such user [$user]!

TXT
    and return
    unless $u;
  
  my $r = $dbh->selectall_arrayref($sql->sth('user roles'), { Slice => {} }, ($u->{id}));
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

USER
@{[$c->dumper( $u)]}

ROLES
@{[$c->dumper( $r)]}

TXT
  
}

sub new_role_user {
  my $c = shift;
  
  my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sql->sth('role'), undef, ($role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

Can't create new role by only digits[$role] in name!

TXT
    and return
    unless $r && $role =~ /\w/;
  $r ||= $dbh->selectrow_hashref($sql->sth('new_role'), undef, ($role)) ;
  
  my $user = $c->stash('user') || $c->param('user');
  my $u =  $dbh->selectrow_hashref($sql->sth('user'), undef, ($user =~ /\D/ ? (undef, $user) : ($user, undef,)));
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such user [$user]!

TXT
    and return
    unless $u;
  
  my $ref = $dbh->selectrow_hashref($sql->sth('ref'), undef, ($r->{id}, $u->{id}));
  $c->render(format=>'txt', text=><<TXT)
$pkg

Allready ref ROLE->USER!

@{[$c->dumper( $ref)]}
TXT
    and return
    if $ref;
  
  $ref = $dbh->selectrow_hashref($sql->sth('new_ref'), undef, ($r->{id}, $u->{id}));
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

Success create ref ROLE->USER!

@{[$c->dumper( $ref)]}
TXT
  
  
}

sub del_role_user {# удалить связь пользователя с ролью
  my $c = shift;
  
  my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sql->sth('role'), undef, ($role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such role [$role]!

TXT
    and return
    unless $r;

  my $user = $c->stash('user') || $c->param('user');
  my $u =  $dbh->selectrow_hashref($sql->sth('user'), undef, ($user =~ /\D/ ? (undef, $user) : ($user, undef,)));
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such user [$user]!

TXT
    and return
    unless $u;
  
  my $ref = $dbh->selectrow_hashref($sql->sth('del ref'), undef, ($r->{id}, $u->{id}));
  $c->render(format=>'txt', text=><<TXT)
$pkg

Success delete ref ROLE[$role]->USER[$user]!

@{[$c->dumper( $ref)]}
TXT
    and return
    if $ref;
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

There is no ref ROLE[$role]->USER[$user]!

TXT
  
}

sub disable_role {
  my $c = shift;
  my $a = shift // 1; # 0-enable 1 - disable
  my $k = {0=>'enable', 1=>'disable',};
  
  my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sql->sth('dsbl/enbl role'), undef, ($a, $role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such role [$role]!

TXT
    and return
    unless $r;
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

Success @{[$k->{$a}]} role!

@{[$c->dumper( $r)]}

TXT
}

sub enable_role {shift->disable_role(0);}


sub role_users {# все пользователи роли по запросу /myadmin/users/:role
  my $c = shift;
  
  my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sql->sth('role'), undef, ($role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such role [$role]!

TXT
    and return
    unless $r;
  
  my $u = $dbh->selectall_arrayref($sql->sth('role_users'), { Slice => {} }, ($r->{id}));
  $c->render(format=>'txt', text=><<TXT);
$pkg

All @{[scalar @$u]} users by role [$r->{name}]

@{[$c->dumper( $u)]}
TXT
}

sub role_routes {# все маршруты роли по запросу /myadmin/routes/:role
  my $c = shift;
  
   my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sql->sth('role'), undef, ($role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such role [$role]!

TXT
    and return
    unless $r;
  
  my $t = $dbh->selectall_arrayref($sql->sth('role_routes'), { Slice => {} }, ($r->{id}));
  $c->render(format=>'txt', text=><<TXT);
$pkg

Total @{[scalar @$t]} routes by role [$r->{name}]

@{[$c->dumper( $t)]}
TXT
}


my @self_routes_cols = qw(request namespace controller action name auth descr);
sub self_routes {# from plugin!
  my $c = shift;
  my $prefix = $init_conf->{prefix};
  my $trust = $init_conf->{trust};
  my $ns = $init_conf->{namespace};
  my $cntr = $init_conf->{controller};

  my $t = <<TABLE;
/$prefix	$ns	$cntr	index	$prefix admin home	1	View main page
/$prefix/role/new/:name	$ns	$cntr	new_role	$prefix create role	1	Add new role by :name
/$prefix/role/del/:role/:user	$ns	$cntr	del_role_user	$prefix del ref role->user	1	Delete ref :user -> :role by user.id|user.login and role.id|role.name.
/$prefix/role/dsbl/:role	$ns	$cntr	disable_role	$prefix disable role->user	1	Disable :role by role.id|role.name.
/$prefix/role/enbl/:role	$ns	$cntr	enable_role	$prefix enable role->user	1	Enable :role by role.id|role.name.
/$prefix/roles	$ns	$cntr	roles	$prefix view roles	1	View roles table
/$prefix/roles/:user	$ns	$cntr	user_roles	$prefix roles of user	1	View roles of :user by id|login
/$prefix/role/:role/:user	$ns	$cntr	new_role_user	$prefix create ref role->user	1	Assign :user to :role by user.id|user.login and role.id|role.name.


/$prefix/route/new	$ns	$cntr	new_route	$prefix create route	1	Add new route by params: request,namespace, controller,....
/$prefix/routes	$ns	$cntr	routes	$prefix view routes	1	View routes table
/$prefix/routes/:role	$ns	$cntr	role_routes	$prefix routes of role	1	All routes of :role by id|name
/$prefix/route/:route/:role	$ns	$cntr	ref	$prefix create ref route->role	1	Assign :route with :role by route.id and role.id|role.name




/$prefix/user/new	$ns	$cntr	new_user	$prefix create user	1	Add new user by params: login,pass,...
/$prefix/user/new/:login/:pass	$ns	$cntr	new_user	$prefix create user st	1	Add new user by :login & :pass
/$prefix/users	$ns	$cntr	users	$prefix view users	1	View users table
/$prefix/users/:role	$ns	$cntr	role_users	$prefix users of role	1	View users of :role by id|name

get foo /sign/in	$ns	$cntr	sign	signin form	0	Login&pass form
post /sign/in	$ns	$cntr	sign	signin params	0	Auth by params
/sign/in/:login/:pass	$ns	$cntr	sign	signin stash	0	Auth by stash
/sign/out	$ns	$cntr	signout	go away	1	Exit

/$prefix/$trust/user/new/:login/:pass	$ns	$cntr	trust_new_user	$prefix/$trust !trust create user!	0	Add new user by :login & :pass and auto assign to role 'Admin' and assign to access this controller!

TABLE
  
  
  my @r = ();
  for my $line (grep /\S+/, split /\n/, $t) {
    my $r = {};
    @$r{@self_routes_cols} = map($_ eq '' ? undef : $_, split /\t/, $line);
    push @r, $r;
  }
  
  return @r;
}


1;

__END__
sub routes000 {
  my $c = shift;
  
  $sth->{insert_routes} ||= $dbh->prepare(<<SQL);
insert into routes (@{[join ',', @self_routes_cols]}) values (@{[join ',', map '?', @self_routes_cols]}) returning *;
SQL

  local $dbh->{AutoCommit} = 0;
  #~ $dbh->begin_work;
  
    $c->render(format=>'txt', text=>"$pkg\n\n". $c->dumper([
  map($dbh->selectrow_hashref($sth->{insert_routes}, undef, @$_{@self_routes_cols},), $c->self_routes)]).<<TXT);

You must kill -HUP (reload/restart) your app! 

TXT
  
  $dbh->rollback;
}
