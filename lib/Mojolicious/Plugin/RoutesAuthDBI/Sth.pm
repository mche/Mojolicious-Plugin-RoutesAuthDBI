package Mojolicious::Plugin::RoutesAuthDBI::Sth;
use Mojo::Base -strict;
#~ use DBIx::POS::Template;

#~ has [qw(dbh)];

sub new {
  my $class = shift;
  my $dbh = shift;
  my $pos = shift;
  my %opt = @_;
  return bless [$dbh, $pos, \%opt], $class;
}

sub sth {
  my ($dbh, $sql, $opt) = @{ shift() };
  my $name = shift;
  my %arg = @_;
  die "No such name[$name] in SQL dict!" unless $sql->{$name};
  my $s = $sql->{$name}->template(%$opt, %arg);
  my $p = $sql->{$name}->param;
  #~ $sth->{$name}{md5_hex( encode_utf8($s))} ||= $dbh->prepare($s); # : $sql->{$name}->sql
  #~ warn "Cached sth [$name]"
    #~ and
  return $dbh->prepare_cached($s)
    if $p && $p->{cached};
  return $dbh->prepare($s);
}

1;

=pod

=encoding utf8

=head1 Mojolicious::Plugin::RoutesAuthDBI::Sth

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Sth - is a DBI statements hub for L<Mojolicious::Plugin::RoutesAuthDBI> classes.

=head1 SYNOPSIS

    my $sth = Mojolicious::Plugin::RoutesAuthDBI::Sth->new(
      $dbh,
      $pos, # SQL dict
      foo => 'bar', # any pairs opts
      ...,
    );
    my $r = $dbh->selectrow_hashref($sth->sth('foo name'));

=head1 DESCRIPTION

Dictionary of DBI statements parses from POS-file.

=head1 new($dbh, $pos, ...)

=head2 $dbh (first in list)

DBI handle

=head2 $pos (second in list)

An SQL dictionary object/instance of the L<DBIx::POS::Template>.

=head2 <any key=>value pairs>


=head1 SEE ALSO

L<Mojolicious::Plugin::RoutesAuthDBI::POS::Pg>

L<DBIx::POS::Template>

=cut
