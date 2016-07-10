package Mojolicious::Plugin::RoutesAuthDBI::Model::Routes;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';

state $Pos = do {
  require Mojolicious::Plugin::RoutesAuthDBI::POS::Access;
  Mojolicious::Plugin::RoutesAuthDBI::POS::Access->new;
};


sub new {
  my $self = shift->SUPER::new(pos=>$Pos);
  $self;
}

sub routes {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectall_arrayref($self->sth->sth('apply routes'), { Slice => {} },);
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