package Mojolicious::Plugin::RoutesAuthDBI::Model::Refs;
use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';

sub new {
  state $self = shift->SUPER::new(@_);
}

sub new_login {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('new login'), undef, (shift, shift))

}

sub login {
  my $self = ref $_[0] ? shift : shift->new;
  
  $self->dbh->selectrow_hashref($self->sth('login'), undef, (shift, shift))

}

1;

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::Model::Logins

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::Model::Logins - SQL model for table "logins".

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

=head1 SEE ALSO

L<DBIx::POS::Template>

=head1 SQL definitions

=head2 new login

=name new login

=desc

=sql

  insert into "{% $schema %}"."{% $tables{logins} %}" (login, pass) values (?,?)
  returning *;

=head2 login

=name login

=desc

=sql

  select *
  from "{% $schema %}"."{% $tables{logins} %}"
  where id=? or login=?;

=cut
