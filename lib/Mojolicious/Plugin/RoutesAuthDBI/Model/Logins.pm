package Mojolicious::Plugin::RoutesAuthDBI::Model::Refs;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(load_class);

state $Pos = load_class('Mojolicious::Plugin::RoutesAuthDBI::POS::Logins')->new;

sub new {
  state $self = shift->SUPER::new(pos=>$Pos);
}

sub new_login {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('new login'), undef, (shift, shift))

}

sub login {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('login'), undef, (shift, shift))

}

1;
