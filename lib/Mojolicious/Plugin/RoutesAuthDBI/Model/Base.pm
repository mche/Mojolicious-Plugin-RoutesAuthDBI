package Mojolicious::Plugin::RoutesAuthDBI::Model::Base;
use Mojo::Base -base;
use Carp 'croak';

has [qw(dbh pos template)];

my $singleton;

has sth => sub {
  my $self = shift;
  require DBIx::POS::Sth;
  DBIx::POS::Sth->new(
    $singleton->dbh,
    $self->pos,
    $self->template,
  );
};



sub singleton {
  $singleton = shift->SUPER::new(@_)
    if @_;
  $singleton;
}

=pod

=encoding utf8

Доброго всем

=head1 Mojolicious::Plugin::RoutesAuthDBI

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 SINOPSYS

Always singleton for process.

Init once in plugin register with dbh and (optional) template defaults only:

  use Mojolicious::Plugin::RoutesAuthDBI::Model::Base;
  Mojolicious::Plugin::RoutesAuthDBI::Model::Base->singleton(dbh=>$dbh, template=>$t);

In child model must define POS dict:

  package Model::Foo;
  use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';
  
  has pos => sub {
    require POS::Foo;
    POS::Foo->new;
  };
  
  sub new {
    my $base = shift->singleton;
    bless $base->dbh->selectrow_hashref($base->sth->sth('foo row'), undef, (@_));
    
  }

In controller:

  ...
  has modelFoo => sub {require Model::Foo; 'Model::Foo';}
  
  sub actionFoo {
    my $c = shift;
    my $foo = $c->modelFoo->new($c->param('id'));
    ...
  
  }

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche[-at-]cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/issues>. Pull requests also welcome.

=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;