package Mojolicious::Plugin::RoutesAuthDBI::Model::Profile;
use Mojo::Base -base;

has [qw(dbh sth)];

has roles => sub {my $self=shift; $self->dbh->selectall_arrayref($self->sth->sth('profile roles'), { Slice => {} }, ($self->{id}))};

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = shift || {};
  bless $self, $class;
  my %arg = @_;
  $self->$_($arg{$_})
    for grep exists $arg{$_},qw(dbh sth);
  $self;
}

1;