package Mojolicious::Plugin::RoutesAuthDBI::Model::Roles;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';

sub new {
  state $self = shift->SUPER::new(@_);
}

sub access {
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectrow_array($self->sth('access role'), undef, $_[0..2]);
}

sub get_role {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('role'), undef, (@_));

}

sub new_role {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('new role'), undef, (@_));

}

sub dsbl_enbl {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('dsbl/enbl role'), undef, (@_));

}

sub profiles {# профили роли
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectall_arrayref($self->sth('role profiles'), { Slice => {} }, (shift));
}

1;

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::Model::Roles

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Model::Roles - SQL model for table "roles".

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

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
