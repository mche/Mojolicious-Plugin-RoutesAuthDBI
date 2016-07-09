package Mojolicious::Plugin::RoutesAuthDBI::Model::Profile;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';

has roles => sub {
  my $self=shift;
  $self->dbh->selectall_arrayref($self->sth->sth('profile roles'), { Slice => {} }, ($self->{id}));
  
};

has pos => sub {
  require Mojolicious::Plugin::RoutesAuthDBI::POS::Access;
  Mojolicious::Plugin::RoutesAuthDBI::POS::Access->new;
};

#~ sub new {
  #~ my $proto = shift;
  #~ my $class = ref($proto) || $proto;
  #~ my $self = shift || {};
  #~ bless $self, $class;
  #~ my %arg = @_;
  #~ $self->$_($arg{$_})
    #~ for grep exists $arg{$_},qw(dbh sth);
  #~ $self;
#~ }

sub new {
  my $base = shift->SUPER::singleton;
  bless $base->dbh->selectrow_hashref($base->sth->sth('profile'), undef, (@_))
    || {};
  
}

1;