package Mojolicious::Plugin::RoutesAuthDBI::Model::OAuth;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';

sub new {
  state $self = shift->SUPER::new(@_);
}

sub site {
  my $self = ref($_[0]) ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('update oauth site'), undef, ( @_, ))
      || $self->dbh->selectrow_hashref($self->sth('new oauth site'), undef, (@_,));
}

sub check_profile {
  my $self = ref($_[0]) ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('check profile oauth'), undef, (@_,));
}

sub user {
  my $self = ref($_[0]) ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('update oauth user'), undef, @_)
      || $self->dbh->selectrow_hashref($self->sth('new oauth user'), undef, @_);
}

sub profile {
  my $self = ref($_[0]) ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('profile by oauth user'), undef, (shift))
}

sub detach {
  my $self = ref($_[0]) ? shift : shift->new;
  $self->dbh->selectrow_hashref($self->sth('отсоединить oauth'), undef, (@_));
}

1;

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::Model::OAuth

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Model::OAuth - SQL model for tables oauth."...".

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

=head1 SEE ALSO

L<DBIx::POS::Template>

=head1 SQL definitions

=head2 update oauth site

=name update oauth site

=desc

=sql

  update "{% $schema %}"."{% $tables{oauth_sites} %}"
  set conf = ?
  where name =?
  returning *;

=head2 new oauth site

=name new oauth site

=desc

=sql

  insert into "{% $schema %}"."{% $tables{oauth_sites} %}" (conf,name) values (?,?)
  returning *;

=head2 update oauth user

=name update oauth user

=desc

=sql

  update "{% $schema %}"."{% $tables{oauth_users} %}"
  set profile = ?, profile_ts=now()
  where site_id =? and user_id=?
  returning 1::int as "old", *;

=head2 new oauth user

=name new oauth user

=desc

=sql

  insert into "{% $schema %}"."{% $tables{oauth_users} %}" (profile, site_id, user_id) values (?,?,?)
  returning 1::int as "new", *;

=head2 profile by oauth user

=name profile by oauth user

=desc

=sql

  select p.*
  from "{% $schema %}"."{% $tables{profiles} %}" p
    join "{% $schema %}"."{% $tables{refs} %}" r on p.id=r.id1

  where r.id2=?;


=head2 check profile oauth

=name check profile oauth

=desc

Только один сайт на профиль

=sql

  select o.*
  from "{% $schema %}"."{% $tables{profiles} %}" p
    join "{% $schema %}"."{% $tables{refs} %}" r on p.id=r.id1
    join "{% $schema %}"."{% $tables{oauth_users} %}" o on o.id=r.id2
  
  where p.id=? and o.site_id=?

=head2 отсоединить oauth

=name отсоединить oauth

=desc

=sql

  delete from "{% $schema %}"."{% $tables{oauth_users} %}" d
  using "{% $schema %}"."{% $tables{refs} %}" r
  where d.site_id = ?
    and r.id1=? -- ид профиля
    and d.id=r.id2
  
  RETURNING d.*, r.id as ref_id;


=head2 profile oauth.users

=name profile oauth.users

=desc

Весь список внешних профилей 

=sql

  select u.*, s.name as site_name
  from "{% $schema %}"."{% $tables{oauth_sites} %}" s
    join "{% $schema %}"."{% $tables{oauth_users} %}" u on s.id = u.site_id
    join "{% $schema %}"."{% $tables{refs} %}" r on u.id=r.id2
  
  where s.id=? and r.id1=? -- профиль ид



=cut