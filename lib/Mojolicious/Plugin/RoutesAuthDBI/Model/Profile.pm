package Mojolicious::Plugin::RoutesAuthDBI::Model::Profile;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';
#~ use Mojolicious::Plugin::RoutesAuthDBI::POS::Access;

has roles => sub {
  my $self=shift;
  $self->dbh->selectall_arrayref($self->sth->sth('profile roles'), { Slice => {} }, ($self->{id}));
  
};

state $pos = do {
  require Mojolicious::Plugin::RoutesAuthDBI::POS::Access;
  Mojolicious::Plugin::RoutesAuthDBI::POS::Access->new;
};


sub new {
  my $self = shift->SUPER::new(pos=>$pos);
  my $r = $self->dbh->selectrow_hashref($self->sth->sth('profile'), undef, (shift, shift,))
    || {};
  @$self{ keys %$r } = values %$r;
  $self;
}

1;

__END__
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