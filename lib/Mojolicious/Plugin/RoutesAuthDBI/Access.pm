package Mojolicious::Plugin::RoutesAuthDBI::Access;
use Mojo::Base -base;
use Exporter 'import'; 
our @EXPORT_OK = qw(load_user validate_user);
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(load_class);
use Mojo::Util qw(md5_sum);

has [qw(app plugin)];

#~ has model_profiles => sub { shift->plugin->model->{Profiles} };
#~ has model => sub {
  #~ { map $_ => load_class("Mojolicious::Plugin::RoutesAuthDBI::Model::$_")->new, qw(Profiles Namespaces Routes Refs Controllers Actions Roles) }
#~ };

sub new {# from plugin! init Class vars
  state $self = shift->SUPER::new(@_);
}

sub load_user {# import for Mojolicious::Plugin::Authentication
  my ($c, $uid) = @_;
  
  my $p = load_class("Mojolicious::Plugin::RoutesAuthDBI::Model::Profiles")->get_profile($uid, undef);
  #~ my $p = $c->model_profiles->get_profile($uid, undef);
  if ($p->{id}) {
    $c->app->log->debug("Loading profile by id=$uid success");
    $p->{pass} = '**********************';
    return $p;
  }
  $c->app->log->debug("Loading profile by id=$uid failed");
  
  return undef;
}

sub validate_user {# import for Mojolicious::Plugin::Authentication
  my ($c, $login, $pass, $extradata) = @_;
  
  return $extradata->{id}
    if $extradata && $extradata->{id};
  
  if (my $p = load_class("Mojolicious::Plugin::RoutesAuthDBI::Model::Profiles")->get_profile(undef, $login)) {
  #~ if (my $p = $c->model_profiles->get_profile(undef, $login)) {
    $c->app->log->debug("Success authenticate by login[$login]/pass[$pass] for profile id[$p->{id}]")
      and return $p->{id}
      if ($p->{pass} eq $pass || $p->{pass} eq md5_sum($pass))
        && !$p->{disable};
    
    $c->app->log->debug("Failure authenticate by login[$login]/pass[$pass]:[@{[md5_sum($pass)]}] for profile id[$p->{id}:$p->{pass}]");
    
    return undef;
  }
  
  $c->app->log->debug("Failure authenticate by login[$login]/pass[$pass]:[@{[md5_sum($pass)]}]");
  
  return undef;
}

sub apply_ns {# Plugin
  my ($self,) = @_;
  my $ns = $self->plugin->model->{Namespaces}->app_ns;
  return unless @$ns;
  my $r = $self->app->routes;
  push @{ $r->namespaces() }, $_->{namespace} for @$ns;
}

sub apply_route {# meth in Plugin
  my ($self, $r_hash) = @_;
  my $r = $self->app->routes;
  
  $self->app->log->debug("Skip disabled route id=[$r_hash->{id}] [$r_hash->{request}]")
    and return undef
    if $r_hash->{disable};
  
  $r_hash->{request} //= $r_hash->{route};
  
  $self->app->log->debug("Skip route @{[$self->app->dumper($r_hash) =~ s/\s+//gr]}: empty request")
    and return undef
    unless $r_hash->{request};
  
  $self->app->log->debug("Skip comment request [$r_hash->{request}]")
    and return undef
    if $r_hash->{request} =~ /^#/;
  
  my @request = grep /\S/, split /\s+/, $r_hash->{request}
    or $self->app->log->debug("Skip route @{[$self->app->dumper($r_hash) =~ s/\s+//gr]}: bad request")
    and return;
  my $nr = $r->route(pop @request);
  $nr->via(@request) if @request;
  
  # STEP AUTH не катит! только один over!
  #~ $nr->over(authenticated=>$r_hash->{auth});
  # STEP ACCESS
  $nr->over(access => $r_hash);
  
  if ( $r_hash->{action} ) {

    my %ns = (namespace => $r_hash->{namespace})
      if $r_hash->{namespace};
      
    if ( $r_hash->{action} =~ /#/ ) { $nr->to($r_hash->{action}, %ns); }
    else { $nr->to(controller=>$r_hash->{controller}, action => $r_hash->{action}, %ns,); }
    
  } elsif ( $r_hash->{callback} ) {
    
    my $cb = eval $r_hash->{callback};
    die "Compile error on callback: [$@]", $self->app->dumper($r_hash)
      if $@;
    $nr->to(cb => $cb);
    
  } else {
    die "No defaults for route: ", $self->app->dumper($r_hash);
  }
  $nr->name($r_hash->{name}) if $r_hash->{name};
  #~ $self->app->log->debug("$pkg generate the route from data row [@{[$self->app->dumper($r_hash) =~ s/\n/ /gr]}]");
  return $nr;
}

sub routes {
  my ($self,) = @_;
  $self->plugin->model->{Routes}->routes;
}

sub access_explicit {# i.e. by refs table
  my ($self, $id1, $id2,) = @_;
  return scalar $self->plugin->model->{Refs}->cnt($id1, $id2);
}


sub access_namespace {#implicit
  my ($self, $namespace, $id2,) = @_;
  return scalar $self->plugin->model->{Namespaces}->access($namespace, $id2);
}

sub access_controller {#implicit
  my ($self, $namespace, $controller, $id2,) = @_;
  my $c = $self->plugin->model->{Controllers}->controller_ns( $controller, ($namespace) x 2,)
    or return undef;
  $self->access_explicit([$c->{id}], $id2);
}

sub access_action {#implicit
  my ($self, $namespace, $controller, $action, $id2,) = @_;
  my $c = $self->plugin->model->{Controllers}->controller_ns( $controller, ($namespace) x 2,)
    or return undef;
  return scalar $self->plugin->model->{Actions}->access( $c->{id}, $action, $id2);
}

sub access_role {#implicit
  my ($self, $role, $id2,) = @_;
  return scalar $self->plugin->model->{Roles}->access($role =~ /\D/ ? (undef, $role) : ($role, undef), $id2);
}

1;

=pod

=encoding utf8

=head1 Mojolicious::Plugin::RoutesAuthDBI::Access

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Access - Generation routes, authentication and controll access to routes trought sintax of ->over(...), see L<Mojolicious::Routes::Route#over>

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 Generate the routes from DB

=over 4

=item * B<route> -> B<actions.action> <- B<controllers> [ <- B<namespaces>]

Route to action method on controller. If no ref from namespace to controller then controller will find on $app->routes->namespaces as usual.

=item * B<routes> -> B<actions.callback>

Route to callback (no ref to controller, defined I<callback> column (as text "sub {...}") in db table B<actions>)

=back

=head2 Access controll flow

There are two ways of flow: explicit and implicit.

=over 4

=item * Explicit access

Check by tables ids: routes, actions, controllers, namespaces. Check refs to profile roles ids.

=item * Implicit access

Access to routes by names: action, controller, namespace, role. This way used for db route to access namespace and for non db routes by syntax:

  $r->route('/foo')->...->to('foo#bar')->over(access=>{auth=>1})->...; 

or

  $r->...->over(access=>{auth=>1, role => <id|name>})->...; # access to route by role id|name

=back

See detail L<Mojolicious::Plugin::RoutesAuthDBI#access>

=head1 SYNOPSIS

    $app->plugin('RoutesAuthDBI', 
        ...
        access => {< options list below >},
        ...
    );

=head1 OPTIONS for plugin

=over 4

=item * B<namespace> - default 'Mojolicious::Plugin::RoutesAuthDBI',

=item * B<module> - default 'Access' (this module),

Both above options determining the module which will play as manager of authentication, accessing and generate routing from DBI source.

=item * B<fail_auth_cb> = sub {my $c = shift;...}

This callback invoke when request need auth route but authentication was failure.

=item * B<fail_access_cb> = sub {my ($c, $route, $r_hash, $u) = @_;...}

This callback invoke when request need auth route but access was failure. $route - L<Mojolicious::Routes::Route> object, $r_hash - route hashref db item, $u - useer hashref.

=back

=head1 EXPORT SUBS

=over 4

=item * B<load_user($c, $uid)> - fetch user record from table profiles by COOKIES. Import for Mojolicious::Plugin::Authentication. Required.

=item * B<validate_user($c, $login, $pass, $extradata)> - fetch login record from table logins by Mojolicious::Plugin::Authentication. Required. If hashref $extradata->{id} then no fetch and $extradata->{id} will return.

=back

=head1 METHODS NEEDS IN PLUGIN

=over 4

=item * B<new(app=> ..., plugin => ...)>

Return new access object.

=item * B<apply_ns()>

Select from db table I<namespaces> ns thus app_ns=1 and push them to $app->namespaces()

=item * B<apply_route($r_hash)>

Heart of routes generation from db tables and not only. Insert to app->routes an hash item $r_hash. DB schema specific. Return new Mojolicious route.

=item * B<routes()>

Fetch records for apply_routes. Must return arrayref of hashrefs routes.

=item * B<access_explicit($id1, $id2)>

Check access to route ($id1 arrayref - either route id or action id or controller id or namespace id) by roles ids ($id2 arrayref). Must return false for deny access or true - allow access.

=item * B<access_namespace($namespace, $id2)>

Check implicit access to route by $namespace for profile roles ids ($id2 arrayref). Must return false for deny access or true - allow access to all actions of this namespace.

=item * B<access_controller($namespace, $controller, $id2)>

Check implicit access to route by $namespace and $controller for profile roles ids ($id2 arrayref). Must return false for deny access or true - allow access to all actions of this controller.

=item * B<access_action($namespace, $controller, $action, $id2)>

Check implicit access to route by $namespace and $controller and $action for profile roles ids ($id2 arrayref). Must return false for deny access or true - allow access to this action.

=item * B<access_role($role, $id2)>

Check implicit access to route by $role (id|name) and profile roles ids ($id2 arrayref). Must return false for deny access or true - allow access.

=back

=head1 SEE ALSO

L<Mojolicious::Plugin::RoutesAuthDBI>

L<Mojolicious::Plugin::RoutesAuthDBI::Sth>

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche [on] cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/issues>. Pull requests welcome also.

=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
