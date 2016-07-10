package Mojolicious::Plugin::RoutesAuthDBI::Model::Controllers;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';

state $Pos = do {
  require Mojolicious::Plugin::RoutesAuthDBI::POS::Access;
  Mojolicious::Plugin::RoutesAuthDBI::POS::Access->new;
};


sub new {
  state $self = shift->SUPER::new(pos=>$Pos);
}

sub controller_ns {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('controller', where => "where controller=? and (namespace=? or (?::varchar is null and namespace is null))"), undef, $_[0..2]);
}

1;

