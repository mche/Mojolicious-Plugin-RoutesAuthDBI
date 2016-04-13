package Mojolicious::Plugin::RoutesAuthDBI::POS::Pg;
use Mojo::Base 'DBIx::POS';
__PACKAGE__->instance (__FILE__);

=pod

=encoding utf8

=head1 Mojolicious::Plugin::RoutesAuthDBI::POS::Pg

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::Pg - POS for PostgreSQL.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    use Mojolicious::Plugin::RoutesAuthDBI::POS::Pg;
    
    my $sql = Mojolicious::Plugin::RoutesAuthDBI::POS::Pg->instance;
    my $sth = $dbh->prepare($sql->{'name foo'});

=head1 SEE ALSO

L<DBIx::POS>

=head1 SQL definitions

=head2 For access methods

=over 4

=item * B<user> 

=name user

=desc

=sql

  select *
  from users
  where id = ? or login=?

=item * B<apply routes> 

=name apply routes

=desc Генерация маршрутов приложения

=sql

  select r.*, ac.controller, ac.namespace, ac.action, ac.callback, ac.id as action_id, ac.controller_id, ac.namespace_id
  from routes r
    join refs rf on r.id=rf.id1
    join 
    (select a.*, c.controller, c.id as controller_id, n.namespace, n.id as namespace_id
      from actions a 
      left join refs r on a.id=r.id2
      left join controllers c on c.id=r.id1
      left join refs r2 on c.id=r2.id2
      left join namespaces n on n.id=r2.id1
    ) ac on rf.id2=ac.id
  order by r.order_by, r.ts;

=item * B<user roles> 

=name user roles

=desc Роли пользователя

=sql

  select g.*
  from
    roles g
    join refs r on g.id=r.id1
  where r.id2=?;
  --and coalesce(g.disable, 0::bit) <> 1::bit

=item * B<cnt refs> 

=name cnt refs

=desc check if ref between id1 and [IDs2] exists

=sql

  select count(*)
  from refs
  where id1 = ? and id2 = ANY(?);

=item * B<access action>

=name access action

=desc доступ к действию

=sql

  select count(r.*)
  from
    namespaces n
    join refs rn on n.id=rn.id1
    join controllers c on c.id=rn.id2
    join refs rc on c.id=rc.id1
    join actions a on a.id=rc.id2
    join refs r on a.id=r.id1
    join roles o on o.id=r.id2
  where
    n.namespace=any(?)
    and c.controller=?
    and a.action=?
    and r.id2=any(?)
    and coalesce(o.disable, 0::bit) <> 1::bit
  ;


=item * B<access controller>

=name access controller

=desc доступ ко всем действиям по имени контроллера и пути

=sql

  select count(r.*)
  from
    namespaces n
    join refs rc on n.id=rc.id1
    join controllers c on c.id=rc.id2
    join refs r on c.id=r.id1
    join roles o on o.id=r.id2
  where
    n.namespace=any(?)
    and c.controller=?
    and r.id2=any(?)
    and coalesce(o.disable, 0::bit) <> 1::bit
  ;

=item * B<access namespace>

=name access namespace

=desc доступ ко всем действиям по имени пути

=sql

  select count(n.*)
  from 
    namespaces n
    join refs r on n.id=r.id1
    join roles o on r.id2=o.id
  where
    n.namespace=any(?)
    and r.id2=any(?)
    and coalesce(o.disable, 0::bit) <> 1::bit
  ;

=item * B<access role>

=name access role

=desc Доступ по роли

=sql

  select count(*)
  from roles
  where (id = ? or name = ?)
    and id = any(?)
  ;

=back

=head2 For administration actions (controller)

=over 4

=item * B<new user> 

=name new user

=desc

=sql

  insert into users (login, pass) values (?,?)
  returning *;

=item * B<role> 

=name role

=desc

=sql

  select *
  from roles
  where id=? or lower(name)=?

=item * B<new role> 

=name new role

=desc

=sql

  insert into roles (name) values (?)
  returning *;

=item * B<dsbl/enbl role> 

=name dsbl/enbl role

=desc

=sql

  update roles set disable=?::bit where id=? or lower(name)=?
  returning *;

=item * B<ref> 

=name ref

=desc

=sql

  select *
  from refs
  where id1=? and id2=?;

=item * B<new ref> 

=name new ref

=desc

=sql

  insert into refs (id1,id2) values (?,?)
  returning *;


=item * B<del ref> 

=name del ref

=desc Delete ref

=sql

  delete from refs
  where id1=? and id2=?
  returning *;

=item * B<controller>

=name controller

=desc Не пустой массив namespace - четко привязанный контроллер, пустой - обязательно не привязанный контроллер

=sql

  select c.*
  from
    controllers c
    left join refs r on c.id=r.id2
    left join namespaces n on n.id=r.id1
  
  where
    (n.namespace=any(?) or (array_length(?::varchar[], 1) is null and n.id is null))
    and c.controller=?

=item * B<new controller> 

=name new controller

=desc

=sql

  insert into controllers (controller, descr)
  values (?,?)
  returning *;

=item * B<new route> 

=name new route

=desc

=sql

  insert into routes (request, name, auth, descr, disable, order_by)
  values (?,?,?,?,?,?,?,?,?)
  returning *;

=item * B<role users> 

=name role users

=desc Пользователи роли

=sql

  select u.*
  from
    users u
    join refs r on u.id=r.id2
  where r.id1=?;

=item * B<role routes> 

=name role routes

=desc Маршруты роли

=sql

  select t.*
  from
    routes t
    join refs r on t.id=r.id1
  where r.id2=?;


=item * B<controllers> 

=name controllers

=desc Список таблицы

=sql

  select * from controllers;

=item * B<namespaces>

=name namespaces

=desc

=sql

  select *
  from namespaces;

=item * B<namespace>

=name namespace

=desc

=sql

  select *
  from namespaces
  where namespace = ?;

=item * B<new namespace>

=name new namespace

=desc

=sql

  insert into namespaces (namespace, descr) values (?,?)
  returning *;


=item * B<actions>

=name actions

=desc Список

=sql

  select a.*, c.namespace, c.controller
  from actions a
    left join refs r on a.id=r.id2
    left join controllers c on c.id=r.id1

=item * B<> 

=name

=desc

=sql


=back


=cut

1;