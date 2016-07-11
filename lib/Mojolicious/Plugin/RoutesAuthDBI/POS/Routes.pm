package Mojolicious::Plugin::RoutesAuthDBI::POS::Routes;
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

=head1 Mojolicious::Plugin::RoutesAuthDBI::POS::Routes

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::Routes - POS-dict for model Routes.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    
    my $pos = Mojolicious::Plugin::RoutesAuthDBI::POS::Routes->new(template=>{tables=>{...}});
    
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

=head2 role routes

=name role routes

=desc

Маршруты роли/действия

=sql

  select t.*
  from
    "{% $schema %}"."{% $tables{routes} %}" t
    join "{% $schema %}"."{% $tables{refs} %}" r on t.id=r.id1
  where r.id2=?;

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

=head2 action routes

=name action routes

=desc

маршрут может быть не привязан к действию

=sql

  select * from (
  select r.*, s.action_id
  from "{% $schema %}"."{% $tables{routes} %}" r
    left join (
     select s.id1, a.id as action_id
     from "{% $schema %}"."{% $tables{refs} %}" s
      join "{% $schema %}"."{% $tables{actions} %}" a on a.id=s.id2
    ) s on r.id=s.id1
  ) s
  {% $where %}; -- action_id is null - free routes; or action(id) routes
  ;


=head2 new route

=name new route

=desc

=sql

  insert into "{% $schema %}"."{% $tables{routes} %}" (request, name, descr, auth, disable, interval_ts)
  values (?,?,?,?,?,?)
  returning *;



=cut

1;