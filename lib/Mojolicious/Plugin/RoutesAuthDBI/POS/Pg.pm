package Mojolicious::Plugin::RoutesAuthDBI::POS::Pg;

use base qw{DBIx::POS::Template};
 
sub new { shift->SUPER::new(__FILE__); }

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::POS::Pg

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::Pg - POS for PostgreSQL.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    use DBIx::POS::Template;
    
    my @path = split(/\//, __FILE__ );
    my $file = join('/', @path[0 .. $#path -1], 'POS/Pg.pm');
    my $pos = DBIx::POS::Template->new($file,);
    my $sth = $dbh->prepare($pos->{'user'});

=head1 SEE ALSO

L<DBIx::POS::Template>

=head1 SQL definitions

=head2 For access methods

=over 4

=item * B<user> 

=name user

=desc

=param

  {cached=>1}

=sql

  select *
  from "{% $schema %}".users
  where id = ? or login=?

=item * B<apply routes> 

=name apply routes

=desc Генерация маршрутов приложения

=sql

  select r.*, ac.controller, ac.namespace, ac.action, ac.callback, ac.id as action_id, ac.controller_id, ac.namespace_id
  from "{% $schema %}".routes r
    join "{% $schema %}".refs rf on r.id=rf.id1
    join 
    (
      select a.*, c.*
      from "{% $schema %}".actions a 
      left join (
        select r.id2 as _id, c.controller, c.id as controller_id, n.namespace, n.id as namespace_id
        from 
          "{% $schema %}".refs r
          join "{% $schema %}".controllers c on r.id1=c.id
          left join "{% $schema %}".refs r2 on c.id=r2.id2
          left join "{% $schema %}".namespaces n on n.id=r2.id1
      ) c on a.id=c._id
    ) ac on rf.id2=ac.id
  order by r.ts - (coalesce(r.interval_ts, 0::int)::varchar || ' second')::interval;

=item * B<user roles> 

=name user roles

=desc Роли пользователя

=param

  {cached=>1}

=sql

  select g.*
  from
    "{% $schema %}".roles g
    join "{% $schema %}".refs r on g.id=r.id1
  where r.id2=?;
  --and coalesce(g.disable, 0::bit) <> 1::bit

=item * B<cnt refs> 

=name cnt refs

=desc check if ref between [IDs1] and [IDs2] exists

=param

  {cached=>1}

=sql

  select count(*)
  from "{% $schema %}".refs
  where id1 = any(?) and id2 = ANY(?);

=item * B<access action>

=name access action

=desc доступ к действию в контроллере (действие-каллбак - доступ проверяется по его ID)

=param

  {cached=>1}

=sql

  select count(r.*)
  from
    "{% $schema %}".refs rc 
    join "{% $schema %}".actions a on a.id=rc.id2
    join "{% $schema %}".refs r on a.id=r.id1
    ---join "{% $schema %}".roles o on o.id=r.id2
  where
    rc.id1=? ---controller id
    and a.action=?
    and r.id2=any(?) --- roles ids
    ---and coalesce(o.disable, 0::bit) <> 1::bit
  ;


=item * B<access namespace>

=name access namespace

=desc доступ ко всем действиям по имени пути

=param

  {cached=>1}

=sql

  select count(n.*)
  from 
    "{% $schema %}".namespaces n
    join "{% $schema %}".refs r on n.id=r.id1
    ---join "{% $schema %}".roles o on r.id2=o.id
  where
    n.namespace=?
    and r.id2=any(?) --- roles ids
    ---and coalesce(o.disable, 0::bit) <> 1::bit
  ;

=item * B<access role>

=name access role

=desc Доступ по роли

=param

  {cached=>1}

=sql

  select count(*)
  from "{% $schema %}".roles
  where (id = ? or name = ?)
    and id = any(?)
    and coalesce(disable, 0::bit) <> 1::bit
  ;

=back

=head2 For administration actions (controller)

=over 4

=item * B<new user> 

=name new user

=desc

=sql

  insert into "{% $schema %}".users (login, pass) values (?,?)
  returning *;

=item * B<role> 

=name role

=desc

=sql

  select *
  from "{% $schema %}".roles
  where id=? or lower(name)=?

=item * B<new role> 

=name new role

=desc

=sql

  insert into "{% $schema %}".roles (name) values (?)
  returning *;

=item * B<dsbl/enbl role> 

=name dsbl/enbl role

=desc

=sql

  update "{% $schema %}".roles set disable=?::bit where id=? or lower(name)=?
  returning *;

=item * B<ref> 

=name ref

=desc

=sql

  select *
  from "{% $schema %}".refs
  where id1=? and id2=?;

=item * B<new ref> 

=name new ref

=desc

=sql

  insert into "{% $schema %}".refs (id1,id2) values (?,?)
  returning *;


=item * B<del ref> 

=name del ref

=desc Delete ref

=sql

  delete from "{% $schema %}".refs
  where id1=? and id2=?
  returning *;

=item * B<controller>

=name controller

=desc Не пустой namespace - четко привязанный контроллер, пустой - обязательно не привязанный контроллер

=param

  {cached=>1}

=sql

  select * from (
  select c.*, n.namespace, n.id as namespace_id, n.descr as namespace_descr
  from
    "{% $schema %}".controllers c
    left join "{% $schema %}".refs r on c.id=r.id2
    left join "{% $schema %}".namespaces n on n.id=r.id1
  ) s
  {% $where %}

=item * B<new controller> 

=name new controller

=desc

=sql

  insert into "{% $schema %}".controllers (controller, descr)
  values (?,?)
  returning *;

=item * B<action routes> 

=name action routes

=desc маршрут может не привязан к действию

=sql

  select * from (
  select r.*, s.action_id
  from "{% $schema %}".routes r
    left join (
     select s.id1, a.id as action_id
     from "{% $schema %}".refs s
      join "{% $schema %}".actions a on a.id=s.id2
    ) s on r.id=s.id1
  ) s
  {% $where %}; -- action_id is null - free routes; or action(id) routes
  ;


=item * B<new route> 

=name new route

=desc

=sql

  insert into "{% $schema %}".routes (request, name, descr, auth, disable, interval_ts)
  values (?,?,?,?,?,?)
  returning *;

=item * B<role users> 

=name role users

=desc Пользователи роли

=sql

  select u.*
  from
    "{% $schema %}".users u
    join "{% $schema %}".refs r on u.id=r.id2
  where r.id1=?;

=item * B<role routes> 

=name role routes

=desc Маршруты роли/действия

=sql

  select t.*
  from
    "{% $schema %}".routes t
    join "{% $schema %}".refs r on t.id=r.id1
  where r.id2=?;


=item * B<controllers> 

=name controllers

=desc Список

=sql

  select c.*, n.namespace, n.id as namespace_id, n.descr as namespace_descr
    from "{% $schema %}".controllers c
    left join "{% $schema %}".refs r on c.id=r.id2
    left join "{% $schema %}".namespaces n on n.id=r.id1
    {% $where %};

=item * B<namespaces>

=name namespaces

=desc Используется в плугине

=sql

  select *
  from "{% $schema %}".namespaces
  {% $where %}
  {% $order %};

=item * B<namespace>

=name namespace

=desc

=sql

  select *
  from "{% $schema %}".namespaces
  where id=? or namespace = ?;

=item * B<new namespace>

=name new namespace

=desc

=sql

  insert into "{% $schema %}".namespaces (namespace, descr, app_ns, interval_ts) values (?,?,?,?)
  returning *;


=item * B<actions>

=name actions

=desc Список действий

=sql

  select * from (
  select a.*, ac.controller_id, ac.controller
  from "{% $schema %}".actions a
    left join (
      select a.id, c.id as controller_id, c.controller
      from "{% $schema %}".actions a
        join "{% $schema %}".refs r on a.id=r.id2
        join "{% $schema %}".controllers c on c.id=r.id1
      ) ac on a.id=ac.id-- действия с контроллером
  ) as a
  {% $where %}

=item * B<new action>

=name new action

=desc 

=sql

  insert into "{% $schema %}".actions (action, callback, descr)
  values (?,?,?)
  returning *;


=item * B<тест> 

=name тест

=desc

=sql

  ыудусе * акщь тест!ж

=back


=cut

1;