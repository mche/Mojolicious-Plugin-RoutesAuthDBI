package Mojolicious::Plugin::RoutesAuthDBI::Model::Namespaces;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';

sub new {
  state $self = shift->SUPER::new(@_);
}

sub app_ns {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectall_arrayref($self->sth('namespaces', where=>"where app_ns=1::bit(1)", order=>"order by ts - (coalesce(interval_ts, 0::int)::varchar || ' second')::interval"), { Slice => {namespace=>1} },);
}

sub access {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_array($self->sth('access namespace'), undef, (shift, shift));
}

sub namespace {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('namespace'), undef, (@_));
}

sub new_namespace {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('new namespace'), undef, (@_));
}

sub namespaces {
  my $self = ref $_[0] ? shift : shift->new;
  $self->dbh->selectall_arrayref($self->sth('namespaces'), { Slice => {} }, );
}


1;

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::Model::Namespaces

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Model::Namespaces - SQL model for table "namespaces".

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

=head1 SEE ALSO

L<DBIx::POS::Template>

=head1 SQL definitions

=head2 namespaces

=name namespaces

=desc

=sql

  select *
  from "{% $schema %}"."{% $tables{namespaces} %}"
  {% $where %}
  {% $order %};

=head2 access namespace

=name access namespace

=desc

доступ ко всем действиям по имени спейса

=param

  {cached=>1}

=sql

  select count(n.*)
  from 
    "{% $schema %}"."{% $tables{namespaces} %}" n
    join "{% $schema %}"."{% $tables{refs} %}" r on n.id=r.id1
    ---join "{% $schema %}"."{% $tables{roles} %}" o on r.id2=o.id
  where
    n.namespace=?
    and r.id2=any(?) --- roles ids
    ---and coalesce(o.disable, 0::bit) <> 1::bit
  ;

=head2 namespace

=name namespace

=desc

=sql

  select *
  from "{% $schema %}"."{% $tables{namespaces} %}"
  where id=? or namespace = ?;

=head2 new namespace

=name new namespace

=desc

=sql

  insert into "{% $schema %}"."{% $tables{namespaces} %}" (namespace, descr, app_ns, interval_ts) values (?,?,?,?)
  returning *;



=cut
