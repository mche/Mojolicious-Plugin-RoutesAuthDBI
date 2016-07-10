package Mojolicious::Plugin::RoutesAuthDBI::POS::Controllers;
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

=head1 Mojolicious::Plugin::RoutesAuthDBI::POS::Controllers

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::Controllers - POS-dict for model Controllers.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    
    my $pos = Mojolicious::Plugin::RoutesAuthDBI::POS::Controllers->new(template=>{tables=>{...}});
    
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


=cut

1;