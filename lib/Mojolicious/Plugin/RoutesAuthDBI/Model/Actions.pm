package Mojolicious::Plugin::RoutesAuthDBI::Model::Actions;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';

state $Pos = do {
  require Mojolicious::Plugin::RoutesAuthDBI::POS::Access;
  Mojolicious::Plugin::RoutesAuthDBI::POS::Access->new;
};


sub new {
  state $self = shift->SUPER::new(pos=>$Pos);
}

sub access {
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectrow_array($self->sth->sth('access action'), undef, ( $_[0..2] ));
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