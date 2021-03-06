package Mojolicious::Plugin::RoutesAuthDBI::POS::Roles;
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

=head1 Mojolicious::Plugin::RoutesAuthDBI::POS::Roles

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::Roles - POS-dict for model Roles.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    
    my $pos = Mojolicious::Plugin::RoutesAuthDBI::POS::Roles->new(template=>{tables=>{...}});
    
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

=head2 role

=name role

=desc

=sql

  select *
  from "{% $schema %}"."{% $tables{roles} %}"
  where id=? or lower(name)=?

=head2 new role

=name new role

=desc

=sql

  insert into "{% $schema %}"."{% $tables{roles} %}" (name) values (?)
  returning *;

=head2 dsbl/enbl role

=name dsbl/enbl role

=desc

=sql

  update "{% $schema %}"."{% $tables{roles} %}" set disable=?::bit where id=? or lower(name)=?
  returning *;

=head2 access role

=name access role

=desc

Доступ по роли

=param

  {cached=>1}

=sql

  select count(*)
  from "{% $schema %}"."{% $tables{roles} %}"
  where (id = ? or name = ?)
    and id = any(?)
    and coalesce(disable, 0::bit) <> 1::bit
  ;

=head2 role profiles

=name role profiles

=desc

Пользователи роли

=sql

  select p.*
  from
    "{% $schema %}"."{% $tables{profiles} %}" p
    join "{% $schema %}"."{% $tables{refs} %}" r on p.id=r.id2
  where r.id1=?;


=cut

1;