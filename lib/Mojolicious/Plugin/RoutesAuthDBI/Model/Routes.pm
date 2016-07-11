package Mojolicious::Plugin::RoutesAuthDBI::Model::Routes;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';
use Mojolicious::Plugin::RoutesAuthDBI::Util qw(load_class);

state $Pos = load_class('Mojolicious::Plugin::RoutesAuthDBI::POS::Routes')->new;


sub new {
  state $self = shift->SUPER::new(pos=>$Pos);
}

sub routes {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectall_arrayref($self->sth->sth('apply routes'), { Slice => {} },);
}

sub routes_ref {
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectall_arrayref($self->sth->sth('role routes'), { Slice => {} }, (shift));
}

sub routes_action {# маршруты действия
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectall_arrayref($self->sth->sth('action routes', where=>"where action_id=?"), { Slice => {} }, (shift));
}

sub routes_action_null {# маршруты без действия
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectall_arrayref($self->sth->sth('action routes', where=>"where action_id is null"), { Slice => {} });
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