package Mojolicious::Plugin::RoutesAuthDBI::Model::Profiles;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';


has roles => sub {
  my $self=shift;
  $self->dbh->selectall_arrayref($self->sth('profile roles'), { Slice => {} }, ($self->{id}));
  
};

sub new {
  state $self = shift->SUPER::new(@_);
}

sub get_profile {
  my $self = ref $_[0] ? shift : shift->new;
  my $p = $self->dbh->selectrow_hashref($self->sth('profile'), undef, (shift, shift,));
  bless $p
    if $p;
  $p;
}

sub profiles {
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectall_arrayref($self->sth('profiles'), {Slice=>{}},);
}

sub new_profile {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('new profile'), undef, (shift,));
}

1;

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::Model::Profiles

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Model::Profiles - SQL model for table "profiles".

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

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