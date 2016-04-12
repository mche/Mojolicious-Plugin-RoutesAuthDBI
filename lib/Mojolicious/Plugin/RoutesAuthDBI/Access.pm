package Mojolicious::Plugin::RoutesAuthDBI::Access;
use Mojo::Base -strict;
use Mojolicious::Plugin::RoutesAuthDBI::Sth;#  sth cache
use Exporter 'import'; 
our @EXPORT_OK = qw(load_user validate_user);

my $dbh; # one per class
my $pkg = __PACKAGE__;
my $init_conf;
my $sth;#sth hub

=pod

=encoding utf8

=head1 Mojolicious::Plugin::RoutesAuthDBI::Access

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Access - Generation routes, authentication and controll access to routes trought sintax of ->over(...), see L<Mojolicious::Routes::Route#over>

=head1 DIAGRAM DB DESIGN

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head2 Access controll flow

=over 4

=item * B<routes> -> B<roles> -> B<users>

=item * B<controllers> -> B<roles> -> B<users>

Access to routes of any actions on controller.

  $r->...->to('foo#bar')->over(access=>{auth=>1}); # check access to route by controller name Foo.pm.

=item * B<roles>

Access to route (which not in db) by role id|name

  $r->...->over(access=>{auth=>1, role => <id|name>})->...

=back

=head2 Generate the routes from DBI

=over 4

=item * B<route> -> B<actions.action> <- B<controllers>

Route to action method on controller

=item * B<routes> -> B<actions.callback>

Route to callback (no ref to controller, defined I<callback> column (as text "sub {...}") in db table B<actions>)

=back


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

=head1 METHODS NEEDS IN PLUGIN

=over 4

=item * B<init_class()>

Make initialization of class vars: $dbh, $sth, $init_conf. Return $self object.

=item * B<apply_route($self, $app, $r_hash)>

Insert to app->routes an hash item $r_hash. DB schema specific. Return new Mojolicious route.

=item * B<db_routes()>

Fetch records for apply_routes. Must return arrayref of hashrefs routes.

=item * B<load_user_roles($self, $c, $uid)>

Fetch records roles for session user. Must return arrayref of hashrefs roles.

=item * B<access_route($self, $c, $id1, $id2)>

Check access to route ($id1) by user roles ids ($id2 arrayref). Must return false for deny access or true - allow access.

=item * B<access_controller($self, $c, $r, $id2)>

Check access to route by $r->{namespace} and $r->{controller} for user roles ids ($id2 arrayref). Must return false for deny access or true - allow access to all actions of this controller.

=item * B<access_role($self, $c, $r, $id2)>

Check access to route by role id|name ($r->{role}) and user roles ids ($id2 arrayref). Must return false for deny access or true - allow access.

=back

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche [on] cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/issues>. Pull requests welcome also.

=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

sub init_class {# from plugin! init Class vars
	my $c = shift;
	my %args = @_;
  $init_conf ||= $c;
	$c->{dbh} ||= $dbh ||=  $args{dbh};
	$dbh ||= $c->{dbh};
  $c->{pos} ||= $args{pos} || $c->{namespace}.'::POS::Pg';
	$c->{sth} ||= $sth ||= $args{sth} ||=( bless [$dbh, {}], $c->{namespace}.'::Sth' )->init(pos=>$c->{pos});#sth cache
	$sth ||= $c->{sth};
	return $c;
}

sub load_user {# import for Mojolicious::Plugin::Authentication
	my ($c, $uid) = @_;
	my $u = $dbh->selectrow_hashref($sth->sth('user'), undef, ($uid, undef));
  $c->app->log->debug("Loading user by id=$uid ". ($u ? 'success' : 'failed'));
  $u->{pass} = '**********************' if $u;
  return $u;
}

sub validate_user {# import for Mojolicious::Plugin::Authentication
  my ($c, $login, $pass, $extradata) = @_;
  if (my $u = $dbh->selectrow_hashref($sth->sth('user'), undef, (undef, $login))) {
    return $u->{id}
      if $u->{pass} eq $pass  && !$u->{disable};
  }
  return undef;
}

sub apply_route {# meth in Plugin
  my ($self, $app, $r_hash) = @_;
  my $r = $app->routes;
  
  $app->log->debug("Skip disabled route id=[$r_hash->{id}] [$r_hash->{request}]")
    and return undef
    if $r_hash->{disable};
  
  $app->log->debug("Skip route id=[$r_hash->{id}] empty request")
    and return undef
    unless $r_hash->{request};
  
  my @request = grep /\S/, split /\s+/, $r_hash->{request}
    or return;
  my $nr = $r->route(pop @request);
  $nr->via(@request) if @request;
  
  # STEP AUTH не катит! только один over!
  #~ $nr->over(authenticated=>$r_hash->{auth});
  # STEP ACCESS
  $nr->over(access => $r_hash);
  
  if ($r_hash->{controller}) {
    $nr->to(controller=>$r_hash->{controller}, action => $r_hash->{action},  $r_hash->{namespace} ? (namespace => $r_hash->{namespace}) : (),);
  } elsif ($r_hash->{callback}) {
    my $cb = eval $r_hash->{callback};
    die "Compile error on callback: [$@]", $app->dumper($r_hash)
      if $@;
    $nr->to(cb => $cb);
  } else {
    die "No defaults for route: ", $app->dumper($r_hash);
  }
  $nr->name($r_hash->{name}) if $r_hash->{name};
  #~ $app->log->debug("$pkg generate the route from data row [@{[$app->dumper($r_hash) =~ s/\n/ /gr]}]");
  return $nr;
}

sub db_routes {
  my ($self, $c, ) = @_;
  $dbh->selectall_arrayref($sth->sth('apply routes'), { Slice => {} },);
}

sub load_user_roles {
	my ($self, $c, $uid) = @_;
	$dbh->selectall_arrayref($sth->sth('user roles'), { Slice => {} }, ($uid));
}

sub access_route {
	my ($self, $c, $id1, $id2,) = @_;
	return scalar $dbh->selectrow_array($sth->sth('cnt refs'), undef, ($id1, $id2));
}

sub access_controller {
	my ($self, $c, $r, $id2,) = @_;
	return scalar $dbh->selectrow_array($sth->sth('access controller'), undef, ($r->{controller}, $r->{namespace},  $id2));
}

sub access_role {
	my ($self, $c, $r, $id2,) = @_;
	return scalar $dbh->selectrow_array($sth->sth('access role'), undef, ($r->{role} =~ /\D/ ? (undef, $r->{role}) : ($r->{role}, undef),), $id2);
}

1;