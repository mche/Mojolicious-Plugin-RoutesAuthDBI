package Mojolicious::Plugin::RoutesAuthDBI::Model::Namespaces;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';

state $Pos = do {
  require Mojolicious::Plugin::RoutesAuthDBI::POS::Access;
  Mojolicious::Plugin::RoutesAuthDBI::POS::Access->new;
};


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