package Mojolicious::Plugin::RoutesAuthDBI::POS::Profiles;
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

=head1 Mojolicious::Plugin::RoutesAuthDBI::POS::Profiles

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::Profiles - POS-dict for model Profiles.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    
    my $pos = Mojolicious::Plugin::RoutesAuthDBI::POS::Profiles->new(template=>{tables=>{...}});
    
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

=head2 profiles

=name profiles

=sql

  select p.*, l.login, l.pass
  from "{% $schema %}"."{% $tables{profiles} %}" p
  left join (
    select l.*, r.id1
    from "{% $schema %}"."{% $tables{refs} %}" r 
      join "{% $schema %}"."{% $tables{logins} %}" l on l.id=r.id2
  ) l on p.id=l.id1

=head2 new profile

=name new profile

=desc

=sql

  insert into "{% $schema %}"."{% $tables{profiles} %}" (names) values (?)
  returning *;

=head2 profile

=name profile

=desc

Load auth profile

=param

  {cached=>1}

=sql

  select p.*, l.login, l.pass
  from "{% $schema %}"."{% $tables{profiles} %}" p
  left join (
    select l.*, r.id1
    from "{% $schema %}"."{% $tables{refs} %}" r 
      join "{% $schema %}"."{% $tables{logins} %}" l on l.id=r.id2
  ) l on p.id=l.id1
  
  where p.id=? or l.login=?

=head2 profile roles

=name profile roles

=desc

Роли пользователя(профиля)

=param

  {cached=>1}

=sql

  select g.*
  from
    "{% $schema %}"."{% $tables{roles} %}" g
    join "{% $schema %}"."{% $tables{refs} %}" r on g.id=r.id1
  where r.id2=?;
  --and coalesce(g.disable, 0::bit) <> 1::bit


=cut

1;