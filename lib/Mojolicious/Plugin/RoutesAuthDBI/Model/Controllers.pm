package Mojolicious::Plugin::RoutesAuthDBI::Model::Controllers;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';

sub new {
  state $self = shift->SUPER::new(@_);
}

sub controller_ns {
  my $self = ref($_[0]) ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('controller', where => "where controller=? and (namespace=? or (?::varchar is null and namespace is null))"), undef, $_[0..2]);
}

sub controller_id_ns {
  my $self = ref($_[0]) ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('controller', where=>"where (id=? or controller=?) and (namespace_id = ? or namespace = ? or (?::varchar is null and namespace is null))"), undef, (@_));
}

sub new_controller {
  my $self = ref($_[0]) ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth->sth('new controller'), undef, (@_));
}

sub controllers {
  my $self = ref($_[0]) ? shift : shift->new;
  
  $self->dbh->selectall_arrayref($self->sth->sth('controllers'), { Slice => {} }, );
}

sub controllers_ns_id {
  my $self = ref($_[0]) ? shift : shift->new;
  
  $self->dbh->selectall_arrayref($self->sth->sth('controllers', where=>"where n.id=? or (?::int is null and n.id is null)"), { Slice => {} }, (@_));
}


1;

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::Model::Controllers

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Model::Controllers - SQL model for table "controllers".

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

=head1 SEE ALSO

L<DBIx::POS::Template>

=head1 SQL definitions

=head2 controller

=name controller

=desc

Не пустой namespace - четко привязанный контроллер, пустой - обязательно не привязанный контроллер

=param

  {cached=>1}

=sql

  select * from (
  select c.*, n.namespace, n.id as namespace_id, n.descr as namespace_descr
  from
    "{% $schema %}"."{% $tables{controllers} %}" c
    left join "{% $schema %}"."{% $tables{refs} %}" r on c.id=r.id2
    left join "{% $schema %}"."{% $tables{namespaces} %}" n on n.id=r.id1
  ) s
  {% $where %}

=head2 new controller

=name new controller

=desc

=sql

  insert into "{% $schema %}"."{% $tables{controllers} %}" (controller, descr)
  values (?,?)
  returning *;

=head2 controllers

=name controllers

=desc

Контроллер либо привязан к спейсу или нет

=sql

  select c.*, n.namespace, n.id as namespace_id, n.descr as namespace_descr
    from "{% $schema %}"."{% $tables{controllers} %}" c
    left join "{% $schema %}"."{% $tables{refs} %}" r on c.id=r.id2
    left join "{% $schema %}"."{% $tables{namespaces} %}" n on n.id=r.id1
    {% $where %};


=cut
