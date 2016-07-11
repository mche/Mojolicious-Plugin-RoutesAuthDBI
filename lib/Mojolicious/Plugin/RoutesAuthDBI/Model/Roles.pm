package Mojolicious::Plugin::RoutesAuthDBI::Model::Roles;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(load_class);

state $Pos = load_class('Mojolicious::Plugin::RoutesAuthDBI::POS::Roles')->new;

sub new {
  state $self = shift->SUPER::new(pos=>$Pos, @_);
}

sub access {
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectrow_array($self->sth->sth('access role'), undef, $_[0..2]);
}

sub get_role {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('role'), undef, (@_));

}

sub new_role {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('new role'), undef, (@_));

}

sub dsbl_enbl {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('dsbl/enbl role'), undef, (@_));

}

sub profiles {# профили роли
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectall_arrayref($self->sth->sth('role profiles'), { Slice => {} }, (shift));
}

1;
