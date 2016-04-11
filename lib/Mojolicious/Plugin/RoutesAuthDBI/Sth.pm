package Mojolicious::Plugin::RoutesAuthDBI::Sth;
use Mojo::Base -strict;
use Mojolicious::Plugin::RoutesAuthDBI::POS::Pg;

=pod

=encoding utf8

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Sth - is a STH hub for L<Mojolicious::Plugin::RoutesAuthDBI>.

=head1 SYNOPSIS

    my $sth = bless [$dbh, {}], 'Mojolicious::Plugin::RoutesAuthDBI::Sth';
    my $r = $dbh->selectrow_hashref($sth->sth('foo name'));

=head1 DESCRIPTION

Dictionary of DBI statements.

=head1 SEE ALSO

L<Mojolicious::Plugin::RoutesAuthDBI::POS>

=cut

my $dbh;
my $sth;

our $sql = Mojolicious::Plugin::RoutesAuthDBI::POS::Pg->instance;


sub sth {
  my ($db, $st) = @{ shift() };
  my $name = shift;
  $dbh ||= $db or die "Not defined dbh DBI handle"; # init dbh once
  warn "Initiate SQL cache $st" unless $sth;
  $sth ||= $st; # init cache once
  $sth ||= {};
  return $sth unless $name;
  die "No such name[$name] in Mojolicious::Plugin::RoutesAuthDBI::POS::Pg!" unless $sql->{$name};
  $sth->{$name} ||= $dbh->prepare($sql->{$name});
}