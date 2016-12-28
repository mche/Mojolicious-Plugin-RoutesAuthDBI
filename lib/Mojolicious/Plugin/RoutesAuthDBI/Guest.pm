package Mojolicious::Plugin::RoutesAuthDBI::Guest;
use Mojo::Base 'Mojolicious::Plugin::Authentication';
use Exporter 'import'; 
our @EXPORT_OK = qw(load_guest);
#~ use Mojolicious::Plugin::RoutesAuthDBI::Util qw(load_class);
use Mojolicious::Plugin::RoutesAuthDBI::Model::Guest;

my $model = Mojolicious::Plugin::RoutesAuthDBI::Model::Guest->new;

sub load_guest {# import for Mojolicious::Plugin::Authentication
  my ($c, $gid) = @_;
  
  my $g = $model->get_guest($gid);
  #~ my $p = $c->model_profiles->get_profile($uid, undef);
  if ($g->{id}) {
    $c->app->log->debug("Loading guest by id=$gid success");
    return $g;
  }
  $c->app->log->debug("Loading guest by id=$gid failed");
  
  return undef;
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
