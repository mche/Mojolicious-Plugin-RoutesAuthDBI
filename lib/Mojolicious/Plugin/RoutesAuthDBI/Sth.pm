package Mojolicious::Plugin::RoutesAuthDBI::Sth;
use Mojo::Base -strict;
use DBIx::POS::Template;
use Digest::MD5 qw( md5_hex );
use Encode qw(encode_utf8);


=pod

=encoding utf8

=head1 Mojolicious::Plugin::RoutesAuthDBI::Sth

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Sth - is a DBI statements hub for L<Mojolicious::Plugin::RoutesAuthDBI> classes.

=head1 SYNOPSIS

    my $sth = bless [$dbh, {}, $schema], 'Mojolicious::Plugin::RoutesAuthDBI::Sth';
    $sth->init(pos => 'POS/Pg.pm');
    my $r = $dbh->selectrow_hashref($sth->sth('foo name'));

=head1 DESCRIPTION

Singleton dictionary of DBI statements.

=head1 SEE ALSO

L<DBIx::POS::Template>

=cut

my $dbh;
my $sth;

our $sql;#
my @path = split(/\//, __FILE__ );

sub init {
  my $self = shift;
  my %arg = @_;
  $sql = DBIx::POS::Template->new(join('/', @path[0 .. $#path -1], $arg{pos}), enc=>'utf8') #$arg{pos} =~ s/::/\//gr . '.pm'
    if $arg{pos};
  return $self;
}

sub sth {
  my ($db, $st, $schema) = @{ shift() };
  my $name = shift;
  my %arg = @_;
  $dbh ||= $db or die "Not defined dbh a DBI handle"; # init dbh once
  #~ warn "Initiate Sth cache $st" unless $sth;
  $sth ||= $st; # init cache once
  $sth ||= {};
  return $sth unless $name;
  die "No such name[$name] in SQL dict!" unless $sql->{$name};
  my $s = $sql->{$name}->template(schema => $schema, %arg);
  $sth->{$name}{md5_hex( encode_utf8($s))} ||= $dbh->prepare($s); # : $sql->{$name}->sql
}

1;