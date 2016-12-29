use Mojo::Base 'Mojolicious';
use Test::More;
use Test::Mojo;
use DBI;

plan skip_all => 'set env TEST_CONN_PG="DBI:Pg:dbname=<db>/<pg_user>/<passwd>" to enable this test'
  unless $ENV{TEST_CONN_PG};

has dbh => sub { DBI->connect(split m|[/]|, $ENV{TEST_CONN_PG}) };

my $config = do 't/config.pm';
my $pkg = __PACKAGE__;

sub startup {
  my $app = shift;
  $app->plugin('RoutesAuthDBI',
    oauth=>{},
    template=>$config,
  );
  my $r = $app->routes;
  $r->get('/')->to( cb => sub {
    my $c = shift;
    $c->render(text=>'ok');
    
  } );
}

my $t = Test::Mojo->new($pkg);

$t->get_ok("/")->status_is(200)
  ->content_is('ok')
  #~ ->content_like(qr/Deny access at auth step/i)
  ;


done_testing();
