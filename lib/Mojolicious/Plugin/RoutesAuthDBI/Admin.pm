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

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 WARN

More or less complete!

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Admin - is a Mojolicious::Controller for manage admin operations on DBI tables: namespaces, controllers, actions, routes, roles, users.

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
        #schema => 'public', # sets from plugin options
    },
    
    admin = {}, # empty hashref sets defaults above
    
    admin => undef, # disables routing of admin controller
    
    admin = > {prefix=>'myadmin', trust => 'foooobaaar'},# admin urls like: /myadmin/foooobaaar/.....



=head1 METHODS NEEDS IN PLUGIN

=over 4

=item * B<self_routes()> - builtin to this access controller routes. Return array of hashrefs routes records for apply route on app. Depends on conf options I<prefix> and I<trust>.

=back

=head1 SEE ALSO

L<Mojolicious::Plugin::RoutesAuthDBI>

L<Mojolicious::Plugin::RoutesAuthDBI::Sth>

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
  $c->{schema} ||= 'public';
  $c->{schema} = qq{"$c->{schema}".};
	$c->{dbh} ||= $dbh ||=  $args{dbh};
	$dbh ||= $c->{dbh};
	$c->{sth} ||= $sth ||= $args{sth} ||= (bless [$dbh, {}, $c->{schema},], $c->{namespace}.'::Sth')->init(pos => $c->{pos} || 'POS/Pg.pm');#sth cache
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
  
  $c->authenticate($c->vars('login','pass'))
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
  
  my ($login, $pass) = $c->vars('login', 'pass');
  
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
  my $ru = $c->ref($rl->{id}, $u->{id});
  
  # CONTROLLER
  my $cc = $dbh->selectrow_hashref($sth->sth('controller'), undef, (($init_conf->{controller}, $init_conf->{namespace}) x 2,));
  $cc ||= $dbh->selectrow_hashref($sth->sth('new controller'), undef, ($init_conf->{controller}, 'admin actions'));
  
  #Namespace
  my $ns = $dbh->selectrow_hashref($sth->sth('namespace'), undef, (undef, $init_conf->{namespace},));
  $ns ||= $dbh->selectrow_hashref($sth->sth('new namespace'), undef, ($init_conf->{namespace}, 'plugin ns!'));
  
  #ref namespace -> controller
  my $nc = $c->ref($ns->{id}, $cc->{id});
  
  #REF namespace->role
  my $cr = $c->ref($ns->{id}, $rl->{id});
  
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
	my ($name) = $c->vars('name');
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
  my ($user) = $c->vars('user');
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
  
  my ($role) = $c->vars('role');
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
  
  $ref = $c->ref($r->{id}, $u->{id});
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

Success create ref ROLE -> USER
===

@{[$c->dumper( $ref)]}
TXT
  
  
}

sub del_role_user {# удалить связь пользователя с ролью
  my $c = shift;
  
  my ($role) = $c->vars('role');
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
  
  my ($role) = $c->vars('role');
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
  
  my ($role) = $c->vars('role');
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
  
   my ($role) = $c->vars('role');
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

CONTROLLERS (@{[scalar @$list]})
===

@{[$c->dumper( $list)]}
TXT
}

sub controller {# /controller/:ns/:controll
  my $c = shift;
  my ($ns, $controll) = $c->vars(qw(ns controll));
  my $list = $dbh->selectall_arrayref($sth->sth('controller', where=>"where (id=? or controller=?) and (namespace_id = ? or namespace = ? or (?::varchar is null and namespace is null))"), { Slice => {} }, ($controll =~ /\D/ ? (undef, $controll) : ($controll, undef), $ns =~ /\D/ ? (undef, $ns) : ($ns, undef), $ns));
  $c->render(format=>'txt', text=><<TXT);
$pkg

CONTROLLER (@{[scalar @$list]})
===

@{[$c->dumper( $list)]}
TXT
}

sub new_controller {
  my $c = shift;
  #~ my $ns = $c->stash('ns') || $c->param('ns') ||  $c->stash('namespace') || $c->param('namespace');
  my ($ns) = $c->vars('ns') || $c->vars('namespace');
  my ($mod) = $c->vars('module');
  my $cn = $dbh->selectrow_hashref($sth->sth('controller'), undef, ($mod, ($ns) x 2,));
  $c->render(format=>'txt', text=><<TXT)
$pkg

Controller already exists
===

@{[$c->dumper( $cn)]}
TXT
  and return
  if $cn;
  my $n = $c->new_namespace($ns) if $ns;
  $cn = $dbh->selectrow_hashref($sth->sth('new controller'), undef, ($mod, undef));
  $c->ref($n->{id}, $cn->{id})
    if $n;
  
  $cn = $dbh->selectrow_hashref($sth->sth('controller'), undef, ($mod, ($ns) x 2,));
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

Success create new controller
===

@{[$c->dumper( $cn)]}
TXT
  return $cn;
}

sub new_namespace {
  my $c = shift;
  my ($ns) = shift ||  $c->vars('ns') || $c->vars('namespace');
  my $n = $dbh->selectrow_hashref($sth->sth('namespace'), undef, ($ns =~ /\D/ ? (undef, $ns) : ($ns, undef,)));
  $c->render(format=>'txt', text=><<TXT)
$pkg

Namespace already exists
===

@{[$c->dumper( $n)]}
TXT
  and return $n
  if $n;
  $n = $dbh->selectrow_hashref($sth->sth('new namespace'), undef, ($ns, undef));
  $c->render(format=>'txt', text=><<TXT);
$pkg

Success create new namespace
===

@{[$c->dumper( $n)]}
TXT
  return $n;
  
}

sub actions {
  my $c = shift;
  my $list = $dbh->selectall_arrayref($sth->sth('actions'), { Slice => {} }, );
  map {
    $_->{routes} = $dbh->selectall_arrayref($sth->sth('action routes', where=>"where action_id=?"), { Slice => {} }, ($_->{id}));
  } @$list;
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

sub new_route_ns {# показать список мест-имен
  my $c = shift;
  my $list = $dbh->selectall_arrayref($sth->sth('namespaces'), { Slice => {} }, );
  $c->render(format=>'txt', text=><<TXT);
$pkg

1. Для нового маршрута укажите имя namespace или его ID или undef.
Новый можно ввести.

Namespaces (@{[scalar @$list]})
===

@{[$c->dumper( $list )]}
TXT
}

sub new_route_c {# показать список контроллеров
  my $c = shift;
  my ($ns) = $c->vars('ns');
  $ns = $dbh->selectrow_hashref($sth->sth('namespace'), undef, ($ns =~ /\D/ ? (undef, $ns) : ($ns, undef,)))
    || {namespace => $ns};
  my $list = $dbh->selectall_arrayref($sth->sth('controllers', where=>"where n.id=? or (?::int is null and n.id is null)"), { Slice => {} }, ($ns->{id}, $ns->{id}));
  $c->render(format=>'txt', text=><<TXT);
$pkg

1. namespace = [$ns->{id}:$ns->{namespace}]

Указать имя или ID контроллера или ввести новое имя

Controllers (@{[scalar @$list]})
===

@{[$c->dumper( $list )]}
TXT
}

sub new_route_a {# показать список действий
  my $c = shift;
  my ($ns, $controll) = $c->vars('ns', 'controll');
  
  $ns = $dbh->selectrow_hashref($sth->sth('namespace'), undef, ($ns =~ /\D/ ? (undef, $ns) : ($ns, undef,)))
    || {namespace => $ns};
  
  $controll = $dbh->selectrow_hashref($sth->sth('controllers', where=>"where (n.id=? or (?::varchar is null and n.id is null)) and (c.id=? or c.controller=?)"), undef, ($ns->{id}, $ns->{id}, $controll =~ /\D/ ? (undef, $controll) : ($controll, undef,), ))
    || {controller=>$controll};
  
  my $list = $dbh->selectall_arrayref($sth->sth('actions', where=>"where controller_id=?"), { Slice => {} }, ($controll->{id}));
  my $list2 = $dbh->selectall_arrayref($sth->sth('actions', where=>"where controller_id is null"), { Slice => {} }, ());
  $c->render(format=>'txt', text=><<TXT);
$pkg

1. namespace = [$ns->{id}:$ns->{namespace}]
2. controller = [$controll->{id}:$controll->{controller}]

Указать имя или ID действия из списка или ввести новое имя действия

Actions for selected controller (@{[scalar @$list]})
===
@{[$c->dumper( $list )]}

Actions without controller (@{[scalar @$list2]}):
===
@{[$c->dumper( $list2 )]}

TXT
}

my @route_cols = qw(request name descr auth disable order_by);
sub new_route {# показать маршруты к действию
  my $c = shift;
  my ($ns, $controll, $act) = $c->vars('ns', 'controll', 'act');
  
  $ns = $dbh->selectrow_hashref($sth->sth('namespace'), undef, ($ns =~ /\D/ ? (undef, $ns) : ($ns, undef,)))
    || {namespace => $ns};
  
  $controll = $dbh->selectrow_hashref($sth->sth('controllers', where=>"where (n.id=? or (?::varchar is null and n.id is null)) and (c.id=? or c.controller=?)"), undef, ($ns->{id}, $ns->{id}, $controll =~ /\D/ ? (undef, $controll) : ($controll, undef,), ))
    || {controller=>$controll};
  
  $act = $dbh->selectrow_hashref($sth->sth('actions', where=>"where controller_id=? and (a.id = ? or a.action = ? )"), undef, ($controll->{id}, $act =~ /\D/ ? (undef, $act) : ($act, undef,),))
    || $dbh->selectrow_hashref($sth->sth('actions', where=>"where controller_id is null and (a.id = ? or a.action = ? )"), undef, ($act =~ /\D/ ? (undef, $act) : ($act, undef,),))
    || {action => $act};
  
  # Проверка на похожий $request ?? TODO
  my $route = {};
  @$route{@route_cols, 'id'} = $c->vars(@route_cols, 'id',);

  my @save = ();
  ($route->{id} || ($route->{request} && $route->{name}))
    && (@save = $c->route_save($ns, $controll, $act, $route))
    && $c->render(format=>'txt', text=><<TXT)
$pkg

Success done save!

Namespace:
===
@{[$c->dumper( $save[0] )]}

Controller:
===
@{[$c->dumper( $save[1] )]}

Action:
===
@{[$c->dumper( $save[2] )]}

Route:
===
@{[$c->dumper( $save[3] )]}

Refs:
===
@{[$c->dumper( $save[4] )]}

TXT
    && return $c
  ;
  
  
  # маршруты действия
  my $list = $act->{id} ? $dbh->selectall_arrayref($sth->sth('action routes', where=>'where action_id=?'), { Slice => {} }, ($act->{id}))
    : [];
  # свободные маршруты
  my $list2 = $act->{id} ? $dbh->selectall_arrayref($sth->sth('action routes', where=>'where action_id is null'), { Slice => {} }, ())
    : [];
  
  $c->render(format=>'txt', text=><<TXT);
$pkg

1. namespace = [$ns->{id}:$ns->{namespace}]
2. controller = [$controll->{id}:$controll->{controller}]
3. action = [$act->{id}:$act->{action}]

Указано: 
@{[map ("$_=$route->{$_}\n", @route_cols)]}

Указать параметры маршрута (?request=/x/y/:z&name=xyz&descr=...):

* request (request=GET POST /foo/:bar)
* name (name=foo_bar)
- descr (descr=пояснение такое)
- auth (auth=1) (auth='only')
- disable (disable=1)
- order_by (order_by=123)

Exists routes for selected action (@{[$list ? scalar @$list : 0]})
===
@{[$c->dumper( $list )]}

Free routes (@{[$list2 ? scalar @$list2 : 0]})
===
@{[$c->dumper( $list2 )]}

TXT
  
}

sub route_save {
  my $c = shift;
  my ($ns, $controll, $act, $route) = @_;
  local $dbh->{AutoCommit} = 0;
  $ns = $dbh->selectrow_hashref($sth->sth('new namespace'), undef, (@$ns{qw(namespace descr)}))
    if $ns->{namespace} && ! $ns->{id};
  $controll = $dbh->selectrow_hashref($sth->sth('new controller'), undef, (@$controll{qw(controller descr)}))
    unless $controll->{id};
  $act = $dbh->selectrow_hashref($sth->sth('new action'), undef, (@$act{qw(action callback descr)}))
    unless $act->{id};
    
  $route = $dbh->selectrow_hashref($sth->sth('new route'), undef, (@$route{@route_cols}))
    unless $route->{id};
  my $ref = [map {
    $c->ref($$_[0]{id}, $$_[1]{id},) if $$_[0]{id} && $$_[1]{id};
  } ([$ns, $controll], [$controll, $act], [$route, $act],)];
  $dbh->commit;
  return ($ns, $controll, $act, $route, $ref);

}

sub vars {# получить из stash || param
  my $c = shift;

  return map {
    my $var = $c->stash($_) || $c->param($_);
    $var = undef if defined($var) && $var eq 'undef';
    $var;
  } @_;
}

sub ref {# get or save
  my $c = shift;
  my ($id1, $id2) = @_;
    #~ $c->app->log->debug($c->dumper(\@_));
  $dbh->selectrow_hashref($sth->sth('ref'), undef, ($id1, $id2,))
    || $dbh->selectrow_hashref($sth->sth('new ref'), undef, ($id1, $id2,));
}



my @self_routes_cols = qw(request action name auth descr);
sub self_routes {# from plugin!
  my $c = shift;
  my $prefix = $init_conf->{prefix};
  my $trust = $init_conf->{trust};

  my $t = <<TABLE;
/$prefix	index	admin home	1	View main page
#
# Namespaces, controllers, actions
#
/$prefix/controllers	controllers	$prefix controllers	1	Controllers list
/$prefix/controller/new/:ns/:module	new_controller	$prefix new_controller	1	Add new controller by :ns and :module
/$prefix/controller/:ns/:controll	controller	$prefix controller	1	View a controller (ID and name for NS and controller)
/$prefix/actions	actions	$prefix actions	1	Actions list
#
# Роли и доступ
#
/$prefix/role/new/:name	new_role	$prefix create role	1	Add new role by :name
/$prefix/role/del/:role/:user	del_role_user	$prefix del ref role->user	1	Delete ref :user -> :role by user.id|user.login and role.id|role.name.
/$prefix/role/dsbl/:role	disable_role	$prefix disable role->user	1	Disable :role by role.id|role.name.
/$prefix/role/enbl/:role	enable_role	$prefix enable role->user	1	Enable :role by role.id|role.name.
/$prefix/roles	roles	$prefix view roles	1	View roles table
/$prefix/roles/:user	user_roles	$prefix roles of user	1	View roles of :user by id|login
/$prefix/role/:role/:user	new_role_user	$prefix create ref role->user	1	Assign :user to :role by user.id|user.login and role.id|role.name.
#
# Последовательный ввод нового маршрута
#
/$prefix/route/new	new_route_ns	$prefix create route step ns	1	Step namespace
/$prefix/route/new/:ns	new_route_c	$prefix create route step controll	1	Step controller
/$prefix/route/new/:ns/:controll	new_route_a	$prefix create route step action	1	Step action
/$prefix/route/new/:ns/:controll/:act	new_route	$prefix create route step request	1	Step request. Params: request, name, auth, descr, ....
/$prefix/route/new/:ns/:controll/:act/:id	new_route	$prefix create route step exist route	1	Step by route id to assign to ns-controller-action
#
# Маршруты и доступ
#
/$prefix/routes	routes	$prefix view routes	1	View routes list
/$prefix/routes/:role	role_routes	$prefix routes of role	1	All routes of :role by id|name
/$prefix/route/:route/:role	ref	$prefix create ref route->role	1	Assign :route with :role by route.id and role.id|role.name
#
# Пользователи
#
/$prefix/user/new	new_user	$prefix create user	1	Add new user by params: login,pass,...
/$prefix/user/new/:login/:pass	new_user	$prefix create user st	1	Add new user by :login & :pass
/$prefix/users	users	$prefix view users	1	View users table
/$prefix/users/:role	role_users	$prefix users of role	1	View users of :role by id|name
#
get foo /sign/in	sign	signin form	0	Login&pass form
post /sign/in	sign	signin params	0	Auth by params
/sign/in/:login/:pass	sign	signin stash	0	Auth by stash
/sign/out	signout	go away	1	Exit
#
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



1;
