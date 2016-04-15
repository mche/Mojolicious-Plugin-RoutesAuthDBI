package Mojolicious::Plugin::RoutesAuthDBI::Sth;
use Mojo::Base -strict;
use DBIx::POS;

=pod

=encoding utf8

=head1 Mojolicious::Plugin::RoutesAuthDBI::Sth

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Sth - is a DBI statements hub for L<Mojolicious::Plugin::RoutesAuthDBI> classes.

=head1 SYNOPSIS

    my $sth = bless [$dbh, {}], 'Mojolicious::Plugin::RoutesAuthDBI::Sth';
    $sth->init(pos => 'Mojolicious::Plugin::RoutesAuthDBI::POS::Pg');
    my $r = $dbh->selectrow_hashref($sth->sth('foo name'));

=head1 DESCRIPTION

Singleton dictionary of DBI statements.

=head1 SEE ALSO

L<DBIx::POS>

=cut

my $dbh;
my $sth;

our $sql;# = Mojolicious::Plugin::RoutesAuthDBI::POS::Pg->instance;
my @path = split(/\//, __FILE__ );

sub init {
  my $self = shift;
  my %arg = @_;
  $sql = DBIx::POS->process(join('/', @path[0 .. $#path -1], 'POS', '').$arg{pos}, 'utf8') #$arg{pos} =~ s/::/\//gr . '.pm'
    if $arg{pos};
  #~ $sql = Mojolicious::Plugin::RoutesAuthDBI::POS::Pg->instance;
  return $self;
}

sub sth {
  my ($db, $st) = @{ shift() };
  my $name = shift;
  $dbh ||= $db or die "Not defined dbh a DBI handle"; # init dbh once
  #~ warn "Initiate Sth cache $st" unless $sth;
  $sth ||= $st; # init cache once
  $sth ||= {};
  return $sth unless $name;
  die "No such name[$name] in SQL dict!" unless $sql->{$name};
  $sth->{$name} ||= $dbh->prepare($sql->{$name});
}

1;