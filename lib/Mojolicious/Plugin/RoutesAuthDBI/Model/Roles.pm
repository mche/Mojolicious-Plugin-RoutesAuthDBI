package Mojolicious::Plugin::RoutesAuthDBI::Model::Roles;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';

state $Pos = do {
  require Mojolicious::Plugin::RoutesAuthDBI::POS::Access;
  Mojolicious::Plugin::RoutesAuthDBI::POS::Access->new;
};


sub new {
  state $self = shift->SUPER::new(pos=>$Pos);
}

sub access {
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectrow_array($self->sth->sth('access role'), undef, $_[0..2]);
}

1;
