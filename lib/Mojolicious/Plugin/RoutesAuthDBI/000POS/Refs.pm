package Mojolicious::Plugin::RoutesAuthDBI::POS::Refs;
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

=head1 Mojolicious::Plugin::RoutesAuthDBI::POS::Refs

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::Refs - POS-dict for model Refs.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    
    my $pos = Mojolicious::Plugin::RoutesAuthDBI::POS::Refs->new(template=>{tables=>{...}});
    
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

=head2 cnt refs

=name cnt refs

=desc

check if ref between [IDs1] and [IDs2] exists

=param

  {cached=>1}

=sql

  select count(*)
  from "{% $schema %}"."{% $tables{refs} %}"
  where id1 = any(?) and id2 = ANY(?);

=head2 ref

=name ref

=desc

=sql

  select *
  from "{% $schema %}"."{% $tables{refs} %}"
  where id1=? and id2=?;

=head2 new ref

=name new ref

=desc

=sql

  insert into "{% $schema %}"."{% $tables{refs} %}" (id1,id2) values (?,?)
  returning *;


=head2 del ref

=name del ref

=desc Delete ref

=sql

  delete from "{% $schema %}"."{% $tables{refs} %}"
  where id=? or (id1=? and id2=?)
  returning *;



=cut

1;