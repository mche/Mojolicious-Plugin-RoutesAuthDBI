package Mojolicious::Plugin::RoutesAuthDBI::POS::Pg;
use Mojo::Base 'DBIx::POS';
__PACKAGE__->instance (__FILE__);

=pod

=encoding utf8

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::Pg - POS for PostgreSQL.

=head1 SYNOPSIS

    use Mojolicious::Plugin::RoutesAuthDBI::POS::Pg;
    
    my $sql = Mojolicious::Plugin::RoutesAuthDBI::POS::Pg->instance;
    my $sth = $dbh->prepare($sql->{'name foo'});

=head1 SEE ALSO

L<DBIx::POS>

=head1 SQL definitions

=head2 For access methods

=over 4

=item * --------------------------------------------------------------------- 

=name user

=desc

=sql

  select *
  from users
  where id = ? or login=?

=item * --------------------------------------------------------------------- 

=name apply routes

=desc Генерация маршрутов приложения

=sql

  select r.*, ac.controller, ac.namespace, ac.action, ac.callback, ac.id as action_id
  from routes r
    join refs rf on r.id=rf.id1
    join 
    (select a.*, c.controller, c.namespace
      from actions a 
      left join refs r on a.id=r.id2
      left join controllers c on c.id=r.id1
    ) ac on rf.id2=ac.id
  order by r.order_by, r.ts;

=item * --------------------------------------------------------------------- 

=name user roles

=desc Роли пользователя

=sql

  select g.*
  from
    roles g
    join refs r on g.id=r.id1
  where r.id2=?;
  --and coalesce(g.disable, 0::bit) <> 1::bit

=item * --------------------------------------------------------------------- 

=name cnt refs

=desc check if ref between id1 and [IDs2] exists

=sql

  select count(*)
  from refs
  where id1 = ? and id2 = ANY(?);

=item * ----------------------------------------------------------------------

=name access controller

=desc доступ ко всем действиям по имени контроллера

=sql

  select count(c.*)
  from 
    controllers c
    join refs r on c.id=r.id1
    join roles o on r.id2=o.id
  where
    lower(c.controller)=lower(?)
    and c.namespace=?
    and r.id2=any(?)
    and coalesce(o.disable, 0::bit) <> 1::bit
  ;

=item * ----------------------------------------------------------------------

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

=item * --------------------------------------------------------------------- 

=name new user

=desc

=sql

  insert into users (login, pass) values (?,?)
  returning *;

=item * --------------------------------------------------------------------- 

=name role

=desc

=sql

  select *
  from roles
  where id=? or lower(name)=?

=item * --------------------------------------------------------------------- 

=name new role

=desc

=sql

  insert into roles (name) values (?)
  returning *;

=item * --------------------------------------------------------------------- 

=name dsbl/enbl role

=desc

=sql

  update roles set disable=?::bit where id=? or lower(name)=?
  returning *;

=item * --------------------------------------------------------------------- 

=name ref

=desc

=sql

  select *
  from refs
  where id1=? and id2=?;

=item * --------------------------------------------------------------------- 

=name new ref

=desc

=sql

  insert into refs (id1,id2) values (?,?)
  returning *;


=item * --------------------------------------------------------------------- 

=name del ref

=desc Delete ref

=sql

  delete from refs
  where id1=? and id2=?
  returning *;

=item * --------------------------------------------------------------------- 

=name controller

=desc

=sql

  select *
  from controllers
  where
    namespace=?
    and lower(controller)=lower(?)

=item * --------------------------------------------------------------------- 

=name new controller

=desc

=sql

  insert into controllers (namespace, controller)
  values (?,?)
  returning *;

=item * --------------------------------------------------------------------- 

=name new route

=desc

=sql

  insert into routes (request, name, auth, descr, disable, order_by)
  values (?,?,?,?,?,?,?,?,?)
  returning *;

=item * --------------------------------------------------------------------- 

=name role users

=desc Пользователи роли

=sql

  select u.*
  from
    users u
    join refs r on u.id=r.id2
  where r.id1=?;

=item * --------------------------------------------------------------------- 

=name role routes

=desc Маршруты роли

=sql

  select t.*
  from
    routes t
    join refs r on t.id=r.id1
  where r.id2=?;


=item * --------------------------------------------------------------------- 

=name controllers

=desc Список таблицы

=sql

  select * from controllers;

=item * --------------------------------------------------------------------- 

=name controller

=desc

=sql

  select * from controllers where namespace = ? and controller = ?;

=item * --------------------------------------------------------------------- 

=name new controller

=desc

=sql

  insert into controllers (namespace, controller) values (?,?)
  returning *;


=item * --------------------------------------------------------------------- 

=name actions

=desc Список

=sql

  select a.*, c.namespace, c.controller
  from actions a
    left join refs r on a.id=r.id2
    left join controllers c on c.id=r.id1

=item * --------------------------------------------------------------------- 

=name

=desc

=sql


=back


=cut

1;