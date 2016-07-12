package Mojolicious::Plugin::RoutesAuthDBI::POS::Namespaces;
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

=head1 Mojolicious::Plugin::RoutesAuthDBI::POS::Namespaces

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::Namespaces - POS-dict for model Namespaces.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    
    my $pos = Mojolicious::Plugin::RoutesAuthDBI::POS::Namespaces->new(template=>{tables=>{...}});
    
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

1;