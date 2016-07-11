package Mojolicious::Plugin::RoutesAuthDBI::Model::Profiles;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(load_class);

state $Pos = load_class('Mojolicious::Plugin::RoutesAuthDBI::POS::Profiles')->new;

has roles => sub {
  my $self=shift;
  $self->dbh->selectall_arrayref($self->sth->sth('profile roles'), { Slice => {} }, ($self->{id}));
  
};

sub new {
  state $self = shift->SUPER::new(pos=>$Pos, @_);
}

sub get_profile {
  my $self = ref $_[0] ? shift : shift->new;
  my $p = $self->dbh->selectrow_hashref($self->sth->sth('profile'), undef, (shift, shift,));
  bless $p
    if $p;
  $p;
}

sub profiles {
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectall_arrayref($self->sth->sth('profiles'), {Slice=>{}},);
}

sub new_profile {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('new profile'), undef, (shift,));
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