package Mojolicious::Plugin::RoutesAuthDBI::Sth;
use Mojo::Base -strict;
use DBIx::POS::Template;


=pod

=encoding utf8

=head1 Mojolicious::Plugin::RoutesAuthDBI::Sth

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Sth - is a DBI statements hub for L<Mojolicious::Plugin::RoutesAuthDBI> classes.

=head1 SYNOPSIS

    my $sth = Mojolicious::Plugin::RoutesAuthDBI::Sth->new(
      $dbh,
      file => 'POS/Pg.pm',
      schema => 'access',
    );
    my $r = $dbh->selectrow_hashref($sth->sth('foo name'));

=head1 DESCRIPTION

Dictionary of DBI statements parses from POS-file.

=head1 OPTIONS on new()

=head2 $dbh

DBI handle

=head2 file

Filename POS perl file, relative from place dir of this package.

=head3 schema

Postgesql db schema name

=head1 SEE ALSO

L<DBIx::POS::Template>

=cut

our %sql;
my @path = split(/\//, __FILE__ );

sub new {
  my $class = shift;
  my $dbh = shift;
  my %opt = @_;
  my $file = join('/', @path[0 .. $#path -1], $opt{file});
  $sql{$file} ||= DBIx::POS::Template->new($file,);
  return bless [$dbh, \%opt, $sql{$file}], $class;
}

sub sth {
  my ($dbh, $opt, $sql) = @{ shift() };
  my $name = shift;
  my %arg = @_;
  die "No such name[$name] in SQL dict!" unless $sql->{$name};
  my $s = $sql->{$name}->template(schema => $opt->{schema}, %arg);
  my $p = $sql->{$name}->param;
  #~ $sth->{$name}{md5_hex( encode_utf8($s))} ||= $dbh->prepare($s); # : $sql->{$name}->sql
  return $dbh->prepare_cached($s)
    if $p && $p->{cached};
  return $dbh->prepare($s);
}

1;