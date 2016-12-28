package Mojolicious::Plugin::RoutesAuthDBI::Model::Guest;
use Mojo::Base 'DBIx::Mojo::Model';

sub new {
  state $self = shift->SUPER::new(@_);
}

sub get_guest {
  my $self = ref($_[0]) ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('guest'), undef, (shift));
}


1;

__DATA__
@@ guest?cached=1
select *
from "{%= $schema %}"."{%= $tables->{guests} %}"
where id=?;


