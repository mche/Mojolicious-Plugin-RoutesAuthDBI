use Mojo::Base 'Mojolicious';
use Test::More;
use Test::Mojo;

sub startup {
  my $r = shift->routes;
  $r->route('/schema/:schema')
    ->to('Schema#schema', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');
  #~ $r->route('/drop/:schema')
    #~ ->to('Schema#schema_drop', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');
}

my $schema = 'тестовая схема 156';
my $seq = '"public"."id 156"';

my $t = Test::Mojo->new(__PACKAGE__);

$t->get_ok(qq{/schema/$schema?oauth_users=oauth2.users&oauth_sites=oauth2.providers&profiles=профили&refs=связи&sequence=$seq&roles=роли доступа&routes=маршруты})
  ->status_is(200)
  ->content_like(qr/table\s+(?:IF NOT EXISTS)?\s*"$schema"\."связи"/i)
  ->content_like(qr/table\s+(?:IF NOT EXISTS)?\s*"$schema"\."профили"/i)
  ->content_like(qr/SEQUENCE\s+$seq/i)
  ->content_like(qr/table\s+(?:IF NOT EXISTS)?\s*"$schema"\."oauth2.providers"/i)
  ->content_like(qr/table\s+(?:IF NOT EXISTS)?\s*"$schema"\."oauth2.users"/i)
  ->content_like(qr/table\s+(?:IF NOT EXISTS)?\s*"$schema"\."роли доступа"/i)
  ->content_like(qr/table\s+(?:IF NOT EXISTS)?\s*"$schema"\."маршруты"/i)
  ;

my $create = $t->tx->res->text;


subtest 'need_conn' => sub {
  plan skip_all => 'set env TEST_CONN_PG="DBI:Pg:dbname=<db>/<pg_user>/<passwd>" to enable this test'
    unless $ENV{TEST_CONN_PG};
  my ($dsn, $user, $pw) = split m|[/]|, $ENV{TEST_CONN_PG};
  require DBI;
  my $dbh = DBI->connect($dsn, $user, $pw);
  is $dbh->do($create), '0E0', 'done';
};


#~ warn $t->tx->res->text;

done_testing();