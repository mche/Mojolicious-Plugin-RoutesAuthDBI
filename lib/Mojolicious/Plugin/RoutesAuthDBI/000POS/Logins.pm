package Mojolicious::Plugin::RoutesAuthDBI::POS::Logins;
use DBIx::POS::Template;
use Hash::Merge qw(merge);
use Mojolicious::Plugin::RoutesAuthDBI::Schema;

my $defaults = $Mojolicious::Plugin::RoutesAuthDBI::Schema::defaults;

sub new {
  my $class= shift;
  my %arg = @_;
  #~ $arg{template} = $arg{template} ? merge($arg{template}, $defaults) : $defaults;
  #~ $class->SUPER::new(__FILE__, %arg);
  DBIx::POS::Template->new(__FILE__, %arg);
}

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::POS::Logins

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::Logins - POS-dict for model Logins.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    
    my $pos = Mojolicious::Plugin::RoutesAuthDBI::POS::Logins->new(template=>{tables=>{...}});
    
    my $sth = $dbh->prepare($pos->{'foo'});

=head1 Methods

One new()

=head2 new()

Input args for new:

=head3 template - hashref

Vars for template system of POS-statements.

=head1 SEE ALSO

L<DBIx::POS::Template>

=head1 SQL definitions

=head2 new login

=name new login

=desc

=sql

  insert into "{% $schema %}"."{% $tables{logins} %}" (login, pass) values (?,?)
  returning *;

=head2 login

=name login

=desc

=sql

  select *
  from "{% $schema %}"."{% $tables{logins} %}"
  where id=? or login=?;

=cut

1;