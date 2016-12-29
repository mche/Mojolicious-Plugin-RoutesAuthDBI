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
    guest=>{},
    template=>$config,
  );
  my $r = $app->routes;
  $r->get('/guest/new')->to( cb => sub {
    my $c = shift;
    
    $c->access->plugin->guest->store($c, {"foo"=>"♥"});
    
    $c->render(text=>'stored');
    
  } );
  
  $r->get('/guest/is')->to( cb => sub {
    my $c = shift;
    
    my $guest = $c->access->plugin->guest->current($c);
    
    return $c->reply->not_found
      unless $guest;
    
    $c->render(json=>$guest);
  });
}

my $t = Test::Mojo->new($pkg);

$t->get_ok("/guest/is")->status_is(404)
  #~ ->content_like(qr/Deny access at auth step/i)
  ;

$t->get_ok("/guest/new")->status_is(200)
  ->content_is('stored')
  #~ ->content_like(qr/Deny access at auth step/i)
  ;

$t->get_ok("/guest/is")->status_is(200)
  #~ ->content_is('stored')
  #~ ->content_like(qr/Deny access at auth step/i)
  ;


done_testing();
