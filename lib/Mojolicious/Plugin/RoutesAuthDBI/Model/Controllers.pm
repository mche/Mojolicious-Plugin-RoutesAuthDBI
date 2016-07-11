package Mojolicious::Plugin::RoutesAuthDBI::Model::Controllers;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(load_class);

state $Pos = load_class('Mojolicious::Plugin::RoutesAuthDBI::POS::Controller')->new;

sub new {
  state $self = shift->SUPER::new(pos=>$Pos);
}

sub controller_ns {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('controller', where => "where controller=? and (namespace=? or (?::varchar is null and namespace is null))"), undef, $_[0..2]);
}

sub controller_id_ns {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('controller', where=>"where (id=? or controller=?) and (namespace_id = ? or namespace = ? or (?::varchar is null and namespace is null))"), undef, (@_));
}

sub new_controller {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('new controller'), undef, (@_));
}

sub controllers {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectall_arrayref($self->sth->sth('controllers'), { Slice => {} }, );
}

sub controllers_ns_id {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectall_arrayref($self->sth->sth('controllers', where=>"where n.id=? or (?::int is null and n.id is null)"), { Slice => {} }, (@_));
}


1;

