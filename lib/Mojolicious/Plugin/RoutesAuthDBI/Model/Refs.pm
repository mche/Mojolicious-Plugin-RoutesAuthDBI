package Mojolicious::Plugin::RoutesAuthDBI::Model::Refs;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';

sub new {
  state $self = shift->SUPER::new(@_);
}

sub cnt {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_array($self->sth('cnt refs'), undef, (shift, shift));
}

sub ref {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('ref'), undef, ($id1, $id2,))
    || $self->dbh->selectrow_hashref($self->sth('new ref'), undef, ($id1, $id2,));
  
}

sub del {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('del ref'), undef, (@_));
}

1;

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::Model::Refs

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Model::Refs - SQL model for table "refs".

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

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
