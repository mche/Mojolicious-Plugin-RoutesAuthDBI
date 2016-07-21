package Mojolicious::Plugin::RoutesAuthDBI::Model::Logins;
use Mojo::Base 'DBIx::Mojo::Model';

sub new {
  state $self = shift->SUPER::new(@_);
}

sub new_login {
  my $self = ref($_[0]) ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('new login'), undef, (shift, shift))

}

sub login {
  my $self = ref($_[0]) ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('login'), undef, (shift, shift))

}

1;

__DATA__
@@ new login
insert into "{%= $schema %}"."{%= $tables->{logins} %}" (login, pass) values (?,?)
returning *;

@@ login
select *
from "{%= $schema %}"."{%= $tables->{logins} %}"
where id=? or login=?;

