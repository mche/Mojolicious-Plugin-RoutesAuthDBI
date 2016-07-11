package Mojolicious::Plugin::RoutesAuthDBI::Model::OAuth;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(load_class);

state $Pos = load_class('Mojolicious::Plugin::RoutesAuthDBI::POS::OAuth2')->new;


sub new {
  state $self = shift->SUPER::new(pos=>$Pos, @_);
}

sub site {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('update oauth site'), undef, ( @_, ))
      || $self->dbh->selectrow_hashref($self->sth->sth('new oauth site'), undef, (@_,));
}

sub check_profile {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('check profile oauth'), undef, (@_,));
}

sub user {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('update oauth user'), undef, @_)
      || $self->dbh->selectrow_hashref($self->sth->sth('new oauth user'), undef, @_);
}

sub profile {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('profile by oauth user'), undef, (shift))
}

sub detach {
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectrow_hashref($self->sth->sth('отсоединить oauth'), undef, (@_));
}

1;
