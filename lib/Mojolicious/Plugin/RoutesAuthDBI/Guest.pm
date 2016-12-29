package Mojolicious::Plugin::RoutesAuthDBI::Guest;
use Mojo::Base -base;#'Mojolicious::Plugin::Authentication'
#~ use Exporter 'import'; 
#~ our @EXPORT_OK = qw(load_guest);
#~ use Mojolicious::Plugin::RoutesAuthDBI::Util qw(load_class);
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(json_enc json_dec);
#~ use Mojolicious::Plugin::RoutesAuthDBI::Model::Guest;

#~ my $model = Mojolicious::Plugin::RoutesAuthDBI::Model::Guest->new;

has [qw(session_key stash_key app plugin model)];

sub new {
  state $self = shift->SUPER::new(@_);
}

sub current {# Fetch the current guest object from the stash - loading it if not already loaded
  my ($self, $c) = @_;
  
  my $stash_key = $self->stash_key;
  
  $self->_loader($c)
    unless
      defined($c->stash($stash_key))
      && ($c->stash($stash_key)->{no_guest}
        || defined($c->stash($stash_key)->{guest}));

  my $guest_def = defined($c->stash($stash_key))
                    && defined($c->stash($stash_key)->{guest});

  return $guest_def ? $c->stash($stash_key)->{guest} : undef;
}

# Unconditionally load the guest based on id in session
sub _loader {
  my ($self, $c) = @_;
  my $gid = $c->session($self->session_key);
  
  my $guest = $self->load($gid)
    if defined $gid;

  if ($guest) {
      $c->stash($self->stash_key => { guest => $guest });
  }
  else {
      # cache result that guest does not exist
      $c->stash($self->stash_key => { no_guest => 1 });
  }
}

sub load {
  my ($self, $gid) = @_;
  
  my $guest = $self->model->get_guest($gid);
  
  if ( $guest && $guest->{id}) {
    my $json = json_dec(delete $guest->{data})
      if $guest->{data};
  
    @$guest{ keys %$json } = values %$json
      if $json;
    
    $self->app->log->debug("Success loading guest by id=$gid");
    return $guest;
  }
  $self->app->log->debug("Failed loading guest by id=$gid");
  
  return undef;
}

 sub reload {
  my ($self, $c) = @_;
  # Clear stash to force a reload of the guest object
  delete $c->stash->{$self->stash_key};
  return $self->current($c);
}

sub is_guest {
  my ($self, $c) = @_;
  return defined($self->current($c)) ? 1 : 0;
}

sub logout {
  my ($self, $c) = @_;
  delete $c->stash->{$self->stash_key};
  delete $c->session->{$self->session_key};
}

 sub store {# new guest
    my ($self, $c, $data) = @_;
    
    $data ||= {};
    #~ $data->{UA} = $c->req->headers->user_agent;
    $data->{headers} = $c->req->headers->to_hash(1);

    my $guest = $self->model->store(json_enc($data));
    $c->session($self->session_key => $guest->{id});
    $c->stash($self->stash_key => { guest => $guest });
}


1;

=pod

=encoding utf8

=head1 Mojolicious::Plugin::RoutesAuthDBI::Guest

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Guest - session for guest

=head1 SYNOPSIS

    $app->plugin('RoutesAuthDBI', 
        ...
        guest => {< options list below >},
        ...
    );

=head1 OPTIONS for plugin

=over 4

=item * B<namespace> - default 'Mojolicious::Plugin::RoutesAuthDBI',

=item * B<module> - default 'Guest' (this module),

=item * B<> - 

=item * B<> - 

=item * B<> - 

=back

=head1 EXPORT SUBS

=over 4

=item * B<load_guest($c, $gid)> - fetch user record from table profiles by COOKIES. Import for Mojolicious::Plugin::Authentication. Required.

=back

=head1 METHODS

None

=head1 SEE ALSO

L<Mojolicious::Plugin::Authentication>

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche [on] cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/issues>. Pull requests welcome also.

=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
