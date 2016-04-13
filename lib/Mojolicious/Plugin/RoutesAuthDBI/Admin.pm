package Mojolicious::Plugin::RoutesAuthDBI::Admin;
use Mojo::Base 'Mojolicious::Controller';
use Mojolicious::Plugin::RoutesAuthDBI::Sth;#  sth cache

my $dbh; # one per class
my $pkg = __PACKAGE__;
my $init_conf;
my $sth;#sth hub

=pod

=encoding utf8

=head1 Mojolicious::Plugin::RoutesAuthDBI::Admin

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Admin - is a Mojolicious::Controller for manage admin operations on DBI tables: controllers, actions, routes, roles, users.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

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
        prefix => 'admin', # lc(<module>)
        trust => $app->secrets->[0],
    },
    
    admin = {}, # empty hashref sets defaults above
    
    admin => undef, # disables routing of admin controller
    
    admin = > {prefix=>'myadmin', trust => 'foooobaaar'},# admin urls like: /myadmin/foooobaaar/.....



=head1 METHODS NEEDS IN PLUGIN

=over 4

=item * B<self_routes()> - builtin this access controller routes. Return array of hashrefs routes records for apply route on app. Depends on conf options I<prefix> and I<trust>.

=back

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche [on] cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/issues>. Pull requests also welcome.

=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

sub init_class {# from plugin! init Class vars
	my $c = shift;
	my %args = @_;
  $init_conf ||= $c;
  $c->{prefix} =~ s/^\///;
  $c->{trust} =~ s/\W/-/g;
	$c->{dbh} ||= $dbh ||=  $args{dbh};
	$dbh ||= $c->{dbh};
  $c->{pos} ||= $args{pos} || $c->{namespace}.'::POS::Pg';
	$c->{sth} ||= $sth ||= $args{sth} ||= (bless [$dbh, {}], $c->{namespace}.'::Sth')->init(pos => $c->{pos});#sth cache
	$sth ||= $c->{sth};
    
	return $c;
}


sub index {
  my $c = shift;
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

You are signed as:
@{[$c->dumper( $c->auth_user)]}


ADMIN ROUTES
===

@{[map "$_->{request}\t\t$_->{descr}\n", $c->self_routes]}

TXT
    and return
    if $c->is_user_authenticated;
  
  $c->render(format=>'txt', text=>__PACKAGE__."\n\nYou are not signed!!! To sign in/up go to /sign/<login>/<pass>");
}

sub sign {
  my $c = shift;
  
  $c->authenticate($c->stash('login') || $c->param('login'), $c->stash('pass') || $c->param('pass'))
    and $c->redirect_to("admin home")
    #~ and $c->render(format=>'txt', text=>__PACKAGE__ . "\n\nSuccessfull signed! ".$c->dumper( $c->auth_user))
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
  ($r = $dbh->selectrow_hashref($sth->sth('user'), undef, (undef, $login)))
    and $c->render(format=>'txt', text=><<TXT)
$pkg

User already exists
===

@{[$c->dumper( $r)]}
TXT
    and ($r->{not_new} = '!')
    and return $r;
  
  $r = $dbh->selectrow_hashref($sth->sth('new user'), undef, ($login, $pass));
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

Success sign up new user
===

@{[$c->dumper( $r)]}
TXT
  return $r;
}

sub trust_new_user {
  my $c = shift;
  
  my $u = $c->new_user;
  
  # ROLE
  my $rl = $dbh->selectrow_hashref($sth->sth('role'), undef, (undef, 'admin'));
  $rl ||= $dbh->selectrow_hashref($sth->sth('new role'), undef, ('admin'));
  
  # REF role->user
  my $ru = $dbh->selectrow_hashref($sth->sth('ref'), undef, ($rl->{id}, $u->{id}));
  $ru ||= $dbh->selectrow_hashref($sth->sth('new ref'), undef, ($rl->{id}, $u->{id}));
  
  # CONTROLLER
  my $cc = $dbh->selectrow_hashref($sth->sth('controller'), undef, (([$init_conf->{namespace}]) x 2, $init_conf->{controller}));
  $cc ||= $dbh->selectrow_hashref($sth->sth('new controller'), undef, ($init_conf->{controller}, 'admin actions'));
  
  #Namespace
  my $ns = $dbh->selectrow_hashref($sth->sth('namespace'), undef, ($init_conf->{namespace},));
  $ns ||= $dbh->selectrow_hashref($sth->sth('new namespace'), undef, ($init_conf->{namespace}, 'plugin ns!'));
  
  #ref namespace -> controller
  my $nc = $dbh->selectrow_hashref($sth->sth('ref'), undef, ($ns->{id}, $cc->{id}));
  $nc ||= $dbh->selectrow_hashref($sth->sth('new ref'), undef, ($ns->{id}, $cc->{id}));
  
  #REF namespace->role
  my $cr = $dbh->selectrow_hashref($sth->sth('ref'), undef, ($ns->{id}, $rl->{id}));
  $cr ||= $dbh->selectrow_hashref($sth->sth('new ref'), undef, ($ns->{id}, $rl->{id}));
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

Success sign up new trust-admin-user with whole access to namespace=[$init_conf->{namespace}]
===

USER:
@{[$c->dumper( $u)]}

ROLE:
@{[$c->dumper( $rl)]}

CONTROLLER:
@{[$c->dumper( $cc)]}

NAMESPACE:
@{[$c->dumper( $ns)]}

TXT
}

sub new_role {
	my $c = shift;
	my $name = $c->stash('name');
	my $r = $dbh->selectrow_hashref($sth->sth('role'), undef, (undef, $name));
	$c->render(format=>'txt', text=><<TXT)
$pkg

Role exists
===

@{[$c->dumper( $r)]}

TXT
		and return $c
		if $r;
	$r = $dbh->selectrow_hashref($sth->sth('new role'), undef, ($name));
	
	$c->render(format=>'txt', text=><<TXT);
$pkg

Success created role
===

@{[$c->dumper( $r)]}

TXT
	
}

sub user_roles {
  my $c = shift;
  my $user = $c->stash('user') || $c->param('user');
  my $u =  $dbh->selectrow_hashref($sth->sth('user'), undef, ($user =~ /\D/ ? (undef, $user) : ($user, undef,)));
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such user [$user]
===

TXT
    and return
    unless $u;
  
  my $r = $dbh->selectall_arrayref($sth->sth('user roles'), { Slice => {} }, ($u->{id}));
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

List of user roles (@{[scalar @$r]})
===

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
  my $r = $dbh->selectrow_hashref($sth->sth('role'), undef, ($role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

Can't create new role by only digits[$role] in name
===

TXT
    and return
    unless $r && $role =~ /\w/;
  $r ||= $dbh->selectrow_hashref($sth->sth('new role'), undef, ($role)) ;
  
  my $user = $c->stash('user') || $c->param('user');
  my $u =  $dbh->selectrow_hashref($sth->sth('user'), undef, ($user =~ /\D/ ? (undef, $user) : ($user, undef,)));
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such user [$user]
===

TXT
    and return
    unless $u;
  
  my $ref = $dbh->selectrow_hashref($sth->sth('ref'), undef, ($r->{id}, $u->{id}));
  $c->render(format=>'txt', text=><<TXT)
$pkg

Allready ref ROLE -> USER
===

@{[$c->dumper( $ref)]}
TXT
    and return
    if $ref;
  
  $ref = $dbh->selectrow_hashref($sth->sth('new ref'), undef, ($r->{id}, $u->{id}));
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

Success create ref ROLE -> USER
===

@{[$c->dumper( $ref)]}
TXT
  
  
}

sub del_role_user {# удалить связь пользователя с ролью
  my $c = shift;
  
  my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sth->sth('role'), undef, ($role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such role [$role]
===

TXT
    and return
    unless $r;

  my $user = $c->stash('user') || $c->param('user');
  my $u =  $dbh->selectrow_hashref($sth->sth('user'), undef, ($user =~ /\D/ ? (undef, $user) : ($user, undef,)));
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such user [$user]
===

TXT
    and return
    unless $u;
  
  my $ref = $dbh->selectrow_hashref($sth->sth('del ref'), undef, ($r->{id}, $u->{id}));
  $c->render(format=>'txt', text=><<TXT)
$pkg

Success delete ref ROLE[$role] -> USER[$user]
===

@{[$c->dumper( $ref)]}
TXT
    and return
    if $ref;
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

There is no ref ROLE[$role] -> USER[$user]

TXT
  
}

sub disable_role {
  my $c = shift;
  my $a = shift // 1; # 0-enable 1 - disable
  my $k = {0=>'enable', 1=>'disable',};
  
  my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sth->sth('dsbl/enbl role'), undef, ($a, $role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such role [$role]
===

TXT
    and return
    unless $r;
  
  $c->render(format=>'txt', text=><<TXT)
$pkg

Success @{[$k->{$a}]} role
===

@{[$c->dumper( $r)]}

TXT
}

sub enable_role {shift->disable_role(0);}


sub role_users {# все пользователи роли по запросу /myadmin/users/:role
  my $c = shift;
  
  my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sth->sth('role'), undef, ($role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such role [$role]
===

TXT
    and return
    unless $r;
  
  my $u = $dbh->selectall_arrayref($sth->sth('role users'), { Slice => {} }, ($r->{id}));
  $c->render(format=>'txt', text=><<TXT);
$pkg

All @{[scalar @$u]} users by role [$r->{name}]
===

@{[$c->dumper( $u)]}
TXT
}

sub role_routes {# все маршруты роли по запросу /myadmin/routes/:role
  my $c = shift;
  
   my $role = $c->stash('role') || $c->param('role');
  # ROLE
  my $r = $dbh->selectrow_hashref($sth->sth('role'), undef, ($role =~ /\D/ ? (undef, $role) : ($role, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

No such role [$role]!

TXT
    and return
    unless $r;
  
  my $t = $dbh->selectall_arrayref($sth->sth('role routes'), { Slice => {} }, ($r->{id}));
  $c->render(format=>'txt', text=><<TXT);
$pkg

Total @{[scalar @$t]} routes by role [$r->{name}]

@{[$c->dumper( $t)]}
TXT
}

sub controllers {
  my $c = shift;
  my $list = $dbh->selectall_arrayref($sth->sth('controllers'), { Slice => {} }, );
  $c->render(format=>'txt', text=><<TXT);
$pkg

CONTROLLERS TABLE (@{[scalar @$list]})
===

@{[$c->dumper( $list)]}
TXT
}

sub new_controller {
  my $c = shift;
  my $ns = $c->stash('ns') || $c->param('ns');
  my $mod = $c->stash('module') || $c->param('module');
  my $r = $dbh->selectrow_hashref($sth->sth('controller'), undef, ($ns, $mod));
  $c->render(format=>'txt', text=><<TXT)
$pkg

Controller already exists
===

@{[$c->dumper( $r)]}
TXT
  and return
  if $r;
  $r = $dbh->selectrow_hashref($sth->sth('new controller'), undef, ($ns, $mod));
  $c->render(format=>'txt', text=><<TXT);
$pkg

Success create new controller
===

@{[$c->dumper( $r)]}
TXT
}

sub actions {
  my $c = shift;
  my $list = $dbh->selectall_arrayref($sth->sth('actions'), { Slice => {} }, );
  $c->render(format=>'txt', text=><<TXT);
$pkg

ACTIONS list (@{[scalar @$list]})
===

@{[$c->dumper( $list )]}
TXT
}

sub routes {
  my $c = shift;
  my $list = $dbh->selectall_arrayref($sth->sth('apply routes'), { Slice => {} }, );
  $c->render(format=>'txt', text=><<TXT);
$pkg

ROUTES list (@{[scalar @$list]})
===

@{[$c->dumper( $list )]}
TXT
}


my @self_routes_cols = qw(request action name auth descr);
sub self_routes {# from plugin!
  my $c = shift;
  my $prefix = $init_conf->{prefix};
  my $trust = $init_conf->{trust};

  my $t = <<TABLE;
/$prefix	index	admin home	1	View main page

/$prefix/controllers	controllers	$prefix controllers	1	Controllers list
/$prefix/controller/new/:ns/:module	new_controller	$prefix new_controller	1	Add new controller by :ns and :module
/$prefix/actions	actions	$prefix actions	1	Actions list

/$prefix/role/new/:name	new_role	$prefix create role	1	Add new role by :name
/$prefix/role/del/:role/:user	del_role_user	$prefix del ref role->user	1	Delete ref :user -> :role by user.id|user.login and role.id|role.name.
/$prefix/role/dsbl/:role	disable_role	$prefix disable role->user	1	Disable :role by role.id|role.name.
/$prefix/role/enbl/:role	enable_role	$prefix enable role->user	1	Enable :role by role.id|role.name.
/$prefix/roles	roles	$prefix view roles	1	View roles table
/$prefix/roles/:user	user_roles	$prefix roles of user	1	View roles of :user by id|login
/$prefix/role/:role/:user	new_role_user	$prefix create ref role->user	1	Assign :user to :role by user.id|user.login and role.id|role.name.

/$prefix/route/new	new_route	$prefix create route	1	Add new route by params: request,namespace, controller,....
/$prefix/routes	routes	$prefix view routes	1	View routes list
/$prefix/routes/:role	role_routes	$prefix routes of role	1	All routes of :role by id|name
/$prefix/route/:route/:role	ref	$prefix create ref route->role	1	Assign :route with :role by route.id and role.id|role.name

/$prefix/user/new	new_user	$prefix create user	1	Add new user by params: login,pass,...
/$prefix/user/new/:login/:pass	new_user	$prefix create user st	1	Add new user by :login & :pass
/$prefix/users	users	$prefix view users	1	View users table
/$prefix/users/:role	role_users	$prefix users of role	1	View users of :role by id|name

get foo /sign/in	sign	signin form	0	Login&pass form
post /sign/in	sign	signin params	0	Auth by params
/sign/in/:login/:pass	sign	signin stash	0	Auth by stash
/sign/out	signout	go away	1	Exit

/$prefix/$trust/admin/new/:login/:pass	trust_new_user	$prefix/$trust !trust create user!	0	Add new user by :login & :pass and auto assign to role 'Admin' and assign to access this controller!

TABLE
  
  
  my @r = ();
  for my $line (grep /\S+/, split /\n/, $t) {
    my $r = {};
    @$r{@self_routes_cols} = map($_ eq '' ? undef : $_, split /\t/, $line);
    $r->{namespace} = $init_conf->{namespace};
    $r->{controller} = $init_conf->{controller};
    push @r, $r;
  }
  
  return @r;
}

sub render000 {
  my $c = shift;
  $c->SUPER::render(format=>'txt', text=><<TXT);
$pkg

TXT
  
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
