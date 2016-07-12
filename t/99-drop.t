use Mojo::Base 'Mojolicious';
use Test::More;
use Test::Mojo;

sub startup {
  my $r = shift->routes;
  $r->route('/drop/:schema')
    ->to('Schema#schema_drop', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');
}

my $schema = 'тестовая схема 156';
my $seq = '"public"."id 156"';

my $t = Test::Mojo->new(__PACKAGE__);

$t->get_ok("/drop/$schema?sequence=$seq")
  ->status_is(200)
  ->content_like(qr/drop schema "$schema"/i)
  ;

subtest 'need_conn' => sub {
  plan skip_all => 'set env TEST_CONN_PG="DBI:Pg:dbname=<db>/<pg_user>/<passwd>" to enable this test'
    unless $ENV{TEST_CONN_PG};
  my ($dsn, $user, $pw) = split m|[/]|, $ENV{TEST_CONN_PG};
  require DBI;
  my $dbh = DBI->connect($dsn, $user, $pw);
  is $dbh->do($t->tx->res->text), '0E0', 'done';
};


#~ warn $t->tx->res->text;

done_testing();