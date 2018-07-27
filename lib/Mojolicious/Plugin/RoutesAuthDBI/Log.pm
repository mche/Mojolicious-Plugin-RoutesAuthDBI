package Mojolicious::Plugin::RoutesAuthDBI::Log;
use Mojo::Base -base;#'Mojolicious::Plugin::Authentication'
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(json_enc json_dec);


has [qw(app plugin model)];

sub new {
  state $self = shift->SUPER::new(@_);
}



1;

=pod

=encoding utf8

Доброго всем


=head1 Mojolicious::Plugin::RoutesAuthDBI::Log

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Log - store log in DBI table.

=head1 SYNOPSIS

    $app->plugin('RoutesAuthDBI', 
        ...
        log => {< options list below >},
        ...
    );

=head1 OPTIONS

=over 4

=item * B<namespace> - default 'Mojolicious::Plugin::RoutesAuthDBI',

=item * B<module> - default 'Guest' (this module),

=item * B<disabled> - boolean, disable logging.


=back

=head1 METHODS



=head1 SEE ALSO

L<Mojolicious::Plugin::RoutesAuthDBI>

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche [on] cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/issues>. Pull requests welcome also.

=head1 COPYRIGHT

Copyright 2018+ Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
