package Mojolicious::Plugin::RoutesAuthDBI::Model::Refs;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(load_class);

state $Pos = load_class('Mojolicious::Plugin::RoutesAuthDBI::POS::Refs')->new;

sub new {
  state $self = shift->SUPER::new(pos=>$Pos);
}

sub cnt {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_array($self->sth->sth('cnt refs'), undef, (shift, shift));
}

sub ref {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('ref'), undef, ($id1, $id2,))
    || $self->dbh->selectrow_hashref($self->sth->sth('new ref'), undef, ($id1, $id2,));
  
}

sub del {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('del ref'), undef, (@_));
}

1;
