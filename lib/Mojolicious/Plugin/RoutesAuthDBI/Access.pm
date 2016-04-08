package Mojolicious::Plugin::RoutesAuthDBI::Access;
use Mojo::Base -strict;
use Mojolicious::Plugin::RoutesAuthDBI::PgSQL;#  sth cache
use Exporter 'import'; 
our @EXPORT_OK = qw(load_user validate_user);

my $dbh; # one per class
my $pkg = __PACKAGE__;
my $init_conf;
my $sql;#sth hub

=pod
=encoding utf8

=head NAME

Mojolicious::Plugin::RoutesAuthDBI::Access - Generation routes, authentication and controll access to routes trought sintax of ->over(...), see L<Mojolicious::Routes::Route#over>

=head1 SYNOPSIS

    $app->plugin('RoutesAuthDBI', 
        dbh => $app->dbh,
        auth => {...},
        access => {< options below >},
    );

=over 4

=item * B<namespace> - default 'Mojolicious::Plugin::RoutesAuthDBI',

=item * B<module> - default 'Access' (this module),

Both above options determining the module which will play as manager of authentication, accessing and generate routing from DBI source.

=item * B<fail_auth_cb> = sub {my $c = shift;...}

This callback invoke when request need auth route but authentication was failure.

=item * B<fail_access_cb> = sub {my ($c, $route, $r_hash) = @_;...}

This callback invoke when request need auth route but access was failure. $route - L<Mojolicious::Routes::Route> object, $r_hash - route hashref db item.

=back

=head1 EXPORT SUBS

=over 4

=item * B<load_user($c, $uid)> - fetch user record from table users by COOKIES. Import for Mojolicious::Plugin::Authentication. Required.

=item * B<validate_user($c, $login, $pass, $extradata)> - fetch user record from table users by Mojolicious::Plugin::Authentication. Required.

=back


head1 METHODS NEEDS IN PLUGIN

=over 4

=item * B<init_class()> - make initialization of class vars: $dbh, $sql, $init_conf. Return $self object controller;

=item * B<apply_route($self, $app, $r_hash)> - insert to app->routes an hash item $r_hash. Return new Mojolicious route;

=item * B<table_routes()> - fetch records from table routes. Return arrayref of hashrefs records.

=item * B<load_user_roles($self, $c, $uid)> - fetch records roles for auth user. Return hashref record.

=item * B<access_route($self, $c, $id1, $id2)> - make check access to route by $id1 for user roles ids $id2 arrayref. Return false for deny access or true - allow access.

=item * B<access_controller($self, $c, $r, $id2)> - make check access to route by special route record with request=NULL by $r->{namespace} and $r->{controller} for user roles ids $id2 arrayref. Return false for deny access or true - allow access to all actions of this controller.

=back

=cut

sub init_class {# from plugin! init Class vars
	my $c = shift;
	my $args = {@_};
  $init_conf ||= $c;
	$c->{dbh} ||= $dbh ||=  $args->{dbh};
	$dbh ||= $c->{dbh};
	$c->{sql} ||= $sql ||= $args->{sql} ||= bless [$dbh, {}], $c->{namespace}.'::PgSQL';#sth cache
	$sql ||= $c->{sql};
	return $c;
}

sub load_user {# import for Mojolicious::Plugin::Authentication
	my ($c, $uid) = @_;
	my $u = $dbh->selectrow_hashref($sql->sth('user/id'), undef, ($uid));
  $c->app->log->debug("Loading user by id=$uid ". ($u ? 'success' : 'failed'));
  return $u;
}

sub validate_user {# import for Mojolicious::Plugin::Authentication
  my ($c, $login, $pass, $extradata) = @_;
  if (my $u = $dbh->selectrow_hashref($sql->sth('user/login'), undef, ($login))) {
    return $u->{id}
      if $u->{pass} eq $pass  && !$u->{disable};
  }
  return undef;
}

sub apply_route {# meth in Plugin
  my ($self, $app, $r_hash) = @_;
  my $r = $app->routes;
  return if $r_hash->{disable};
  return unless $r_hash->{request};
  my @request = grep /\S/, split /\s+/, $r_hash->{request}
    or return;
  my $nr = $r->route(pop @request);
  $nr->via(@request) if @request;
  
  # STEP AUTH не катит! только один over!
  #~ $nr->over(authenticated=>$r_hash->{auth});
  # STEP ACCESS
  $nr->over(access => $r_hash);
  
  $nr->to(controller=>$r_hash->{controller}, action => $r_hash->{action},  $r_hash->{namespace} ? (namespace => $r_hash->{namespace}) : (),);
  $nr->name($r_hash->{name}) if $r_hash->{name};
  #~ $app->log->debug("$pkg generate the route from data row [@{[$app->dumper($r_hash) =~ s/\n/ /gr]}]");
  return $nr;
}

sub table_routes {
  my ($self, $c, ) = @_;
  $dbh->selectall_arrayref($sql->sth('all routes'), { Slice => {} },);
}

sub load_user_roles {
	my ($self, $c, $uid) = @_;
	$dbh->selectall_arrayref($sql->sth('user roles'), { Slice => {} }, ($uid));
}

sub access_route {
	my ($self, $c, $id1, $id2,) = @_;
	return scalar $dbh->selectrow_array($sql->sth('cnt refs'), undef, ($id1, $id2));
}

sub access_controller {
	my ($self, $c, $r, $id2,) = @_;
	return scalar $dbh->selectrow_array($sql->sth('access controller'), undef, ($r->{controller}, $r->{namespace},  $id2));
}

1;