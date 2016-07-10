package Mojolicious::Plugin::RoutesAuthDBI::Model::Namespaces;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(load_class);

state $Pos = load_class('Mojolicious::Plugin::RoutesAuthDBI::POS::Namespaces')->new;

sub new {
  state $self = shift->SUPER::new(pos=>$Pos);
}

sub app_ns {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectall_arrayref($self->sth->sth('namespaces', where=>"where app_ns=1::bit(1)", order=>"order by ts - (coalesce(interval_ts, 0::int)::varchar || ' second')::interval"), { Slice => {namespace=>1} },);
}

sub access {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_array($self->sth->sth('access namespace'), undef, (shift, shift));
}

sub namespace {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('namespace'), undef, (@_));
}

sub new_namespace {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('new namespace'), undef, (@_));
}


1;
