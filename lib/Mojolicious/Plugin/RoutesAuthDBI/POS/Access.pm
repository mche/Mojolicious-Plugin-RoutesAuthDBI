package Mojolicious::Plugin::RoutesAuthDBI::POS::Access;
use DBIx::POS::Template;
use Hash::Merge qw(merge);
use Mojolicious::Plugin::RoutesAuthDBI::Schema;

my $defaults = $Mojolicious::Plugin::RoutesAuthDBI::Schema::defaults;

sub new {
  my $class= shift;
  my %arg = @_;
  $arg{template} = $arg{template} ? merge($arg{template}, $defaults) : $defaults;
  #~ $class->SUPER::new(__FILE__, %arg);
  DBIx::POS::Template->instance(__FILE__, %arg);
}

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::POS::Access

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::Access - POS-dict for access statements L<Mojolicious::Plugin::RoutesAuthDBI::Access>.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    
    my $pos = Mojolicious::Plugin::RoutesAuthDBI::POS::Access->new(template=>{tables=>{...}});
    
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

=head2 apply routes>

=name apply routes

=desc

Генерация маршрутов приложения

=sql

  select r.*, ac.controller, ac.namespace, ac.action, ac.callback, ac.id as action_id, ac.controller_id, ac.namespace_id
  from "{% $schema %}"."{% $tables{routes} %}" r
    join "{% $schema %}"."{% $tables{refs} %}" rf on r.id=rf.id1
    join 
    (
      select a.*, c.*
      from "{% $schema %}"."{% $tables{actions} %}" a 
      left join (
        select r.id2 as _id, c.controller, c.id as controller_id, n.namespace, n.id as namespace_id
        from 
          "{% $schema %}"."{% $tables{refs} %}" r
          join "{% $schema %}"."{% $tables{controllers} %}" c on r.id1=c.id
          left join "{% $schema %}"."{% $tables{refs} %}" r2 on c.id=r2.id2
          left join "{% $schema %}"."{% $tables{namespaces} %}" n on n.id=r2.id1
      ) c on a.id=c._id
    ) ac on rf.id2=ac.id
  order by r.ts - (coalesce(r.interval_ts, 0::int)::varchar || ' second')::interval;

=head2 access action

=name access action

=desc

доступ к действию в контроллере (действие-каллбак - доступ проверяется по его ID)

=param

  {cached=>1}

=sql

  select count(r.*)
  from
    "{% $schema %}"."{% $tables{refs} %}" rc 
    join "{% $schema %}"."{% $tables{actions} %}" a on a.id=rc.id2
    join "{% $schema %}"."{% $tables{refs} %}" r on a.id=r.id1
    ---join "{% $schema %}"."{% $tables{roles} %}" o on o.id=r.id2
  where
    rc.id1=? ---controller id
    and a.action=?
    and r.id2=any(?) --- roles ids
    ---and coalesce(o.disable, 0::bit) <> 1::bit
  ;






=cut

1;