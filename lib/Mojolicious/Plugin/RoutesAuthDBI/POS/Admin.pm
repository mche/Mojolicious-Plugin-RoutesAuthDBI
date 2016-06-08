package Mojolicious::Plugin::RoutesAuthDBI::POS::Admin;
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

=head1 Mojolicious::Plugin::RoutesAuthDBI::POS::Admin

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::Admin - POS for PostgreSQL.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    
    my $pos = Mojolicious::Plugin::RoutesAuthDBI::POS::Admin->new(template=>{tables=>{...}});
    
    my $sth = $dbh->prepare($pos->{'user'});

=head1 Methods

One new()

=head2 new()

None input args for new.

=head1 SEE ALSO

L<DBIx::POS::Template>

=head1 SQL definitions

=head2 new profile

=name new profile

=desc

=sql

  insert into "{% $schema %}"."{% $tables{profiles} %}" (names) values (?)
  returning *;

=head2 new login

=name new login

=desc

=sql

  insert into "{% $schema %}"."{% $tables{logins} %}" (login, pass) values (?,?)
  returning *;

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
  where id1=? and id2=?
  returning *;



=head2 new controller

=name new controller

=desc

=sql

  insert into "{% $schema %}"."{% $tables{controllers} %}" (controller, descr)
  values (?,?)
  returning *;

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


=head2 controllers

=name controllers

=desc

=sql

  select c.*, n.namespace, n.id as namespace_id, n.descr as namespace_descr
    from "{% $schema %}"."{% $tables{controllers} %}" c
    left join "{% $schema %}"."{% $tables{refs} %}" r on c.id=r.id2
    left join "{% $schema %}"."{% $tables{namespaces} %}" n on n.id=r.id1
    {% $where %};

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


=head2 actions

=name actions

=desc

Список действий

=sql

  select * from (
  select a.*, ac.controller_id, ac.controller
  from "{% $schema %}"."{% $tables{actions} %}" a
    left join (
      select a.id, c.id as controller_id, c.controller
      from "{% $schema %}"."{% $tables{actions} %}" a
        join "{% $schema %}"."{% $tables{refs} %}" r on a.id=r.id2
        join "{% $schema %}"."{% $tables{controllers} %}" c on c.id=r.id1
      ) ac on a.id=ac.id-- действия с контроллером
  ) as a
  {% $where %}

=head2 new action

=name new action

=desc 

=sql

  insert into "{% $schema %}"."{% $tables{actions} %}" (action, callback, descr)
  values (?,?,?)
  returning *;

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


=head2 тест

=name тест

=desc

тест

=sql

  ыудусе * акщь тест!ж

=cut

1;