package Mojolicious::Plugin::RoutesAuthDBI::POS::OAuth2;
use DBIx::POS::Template;
use Hash::Merge qw(merge);
use Mojolicious::Plugin::RoutesAuthDBI::Schema;

my $defaults = $Mojolicious::Plugin::RoutesAuthDBI::Schema::defaults;

sub new {
  my $class= shift;
  my %arg = @_;
  $arg{template} = $arg{template} ? merge($arg{template}, $defaults) : $defaults;
  #~ $class->SUPER::new(__FILE__, %arg);
  DBIx::POS::Template->new(__FILE__, %arg);
}

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::POS::OAuth2

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::OAuth2 - POS dict for OAuth2.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    
    my $pos = Mojolicious::Plugin::RoutesAuthDBI::POS::OAuth2->new(template=>{tables=>{...}});
    
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

  insert into "{% $schema %}"."{% $tables{oauth_sites} %}" (name,conf) values (?,?)
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

=cut

1;