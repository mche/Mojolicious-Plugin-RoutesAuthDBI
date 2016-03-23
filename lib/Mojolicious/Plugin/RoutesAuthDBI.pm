package Mojolicious::Plugin::RoutesAuthDBI;
use Mojo::Base 'Mojolicious::Plugin';


our $VERSION = '0.01';

sub register {
  my ($plugin, $app, @args) = @_;
  
}

1;

__END__

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI - Generate routes from sql-table and make restrict access to them with users table. Make an auth operations with cookies.

=head1 SYNOPSIS

=head1 DESCRIPTION



=head2 Example routing table records

    Route
    HTTP method(s) (optional)
    and the URL (space delim)
                        Contoller         Method          Route Name
    ------              ---------         -------          ------------
    GET /city/new               City         new_form        city_new_form
    GET /city/:id                   City         show            city_show
    GET /city/edit/:id              City         edit_form       city_edit_form
    GET /cities                   City         index          city_index
    POST /city                   City         save          city_save
    GET /city/delete/:id            City         delete_form     city_delete_form
    DELETE /city/:id                   City         delete          city_delete
    /foo/bar               Foo         bar        foo_bar
    GET POST /foo/baz                   Foo         baz        foo_baz


        # GET /city/new 
        $r->route('/city/new')->via('get')->to(controller => 'city', action => 'new_form')->name('city_new_form');

        # GET /city/123 - show item with id 123
        $r->route('/city/:id')->via('get')->to(controller => 'city', action => 'show')->name('city_show');

        # GET /city/edit/123 - form to edit an item
        $r->route('/city/edit/:id')->via('get')->to(controller => 'city', action => 'edit_form')->name('city_edit_form');

        # GET /cities - list of all items
        $r->route('/cities')->via('get')->to(controller => 'city', action => 'index')->name('cities_index');

        # POST /city - create new item or update the item
        $r->route('/city')->via('post')->to(controller => 'city', action => 'save')->name('city_save');

        # GET /city/delete/123 - form to confirm delete an item id=123
        $r->route('/city/delete/:id')->via('get')->to(controller => 'city', action => 'delete_form')->name('city_delete_form');

        # DELETE /city/123 - delete an item id=123
        $r->route('/city/:id')->via('delete')->to(controller => 'city', action => 'delete')->name('city_delete');
        
        # without HTTP method
        $r->route('/foo/bar')->to(controller => 'Foo', action => 'bar')->name('foo_bar');
        
        # GET or POST /foo/baz 
        $r->route('/foo/baz')->via(['GET', 'POST'])->to(controller => 'Foo', action => 'baz')->name('foo_baz');

=head1 AUTHOR

Mikhail Che, C<< <mche [] cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-mojolicious-plugin-routesauthdbi at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Mojolicious-Plugin-RoutesAuthDBI>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Mojolicious::Plugin::RoutesAuthDBI


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mojolicious-Plugin-RoutesAuthDBI>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Mojolicious-Plugin-RoutesAuthDBI>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Mojolicious-Plugin-RoutesAuthDBI>

=item * Search CPAN

L<http://search.cpan.org/dist/Mojolicious-Plugin-RoutesAuthDBI/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

=cut

