package Mojolicious::Plugin::RoutesAuthDBI::Model::Actions;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(load_class);

state $Pos = load_class('Mojolicious::Plugin::RoutesAuthDBI::POS::Actions')->new;

sub new {
  state $self = shift->SUPER::new(pos=>$Pos);
}

sub access {
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectrow_array($self->sth->sth('access action'), undef, ( $_[0..2] ));
}

sub actions {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectall_arrayref($self->sth->sth('actions'), { Slice => {} }, );
}

sub actions_controller {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectall_arrayref($self->sth->sth('actions', where=>"where controller_id=?"), { Slice => {} }, (shift));
}

sub action_controller {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('actions', where=>"where controller_id=? and (a.id = ? or a.action = ? )"), undef, (@_));
}

sub action_controller_null {# дествие с пустым контроллером
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('actions', where=>"where controller_id is null and (a.id = ? or a.action = ? )"), undef, (@_));
}

sub actions_controller_null {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectall_arrayref($self->sth->sth('actions', where=>"where controller_id is null"), { Slice => {} },);
}

1;

