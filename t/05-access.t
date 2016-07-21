use Mojo::Base 'Mojolicious';
use Test::More;
use Test::Mojo;
use DBI;
use lib 't';

plan skip_all => 'set env TEST_CONN_PG="DBI:Pg:dbname=<db>/<pg_user>/<passwd>" to enable this test'
  unless $ENV{TEST_CONN_PG};

has dbh => sub { DBI->connect(split m|[/]|, $ENV{TEST_CONN_PG})};

my $config = do 't/config.pm';

sub startup {
  my $app = shift;
  $app->plugin('RoutesAuthDBI',
    auth=>{current_user_fn=>'auth_user'},
    admin=>{prefix=>$config->{prefix}, trust=>$config->{trust},},
    template=>$config,
  );
  my $routes = $app->routes;
  push @{ $routes->namespaces }, 'Test';
  
  $routes->route('/noauth')->over(access=>{auth=>0,})
    ->to('install#manual', namespace=>$config->{namespace});
  
  $routes->route('/auth-only')->over(access=>{auth=>'only'})
    ->to('install#manual', namespace=>$config->{namespace});
  
  $routes->get('/authenticated')->over(authenticated => 1)
    ->to('install#manual', namespace=>$config->{namespace});
  
  $routes->route('/test1/:action')->over(access=>{auth=>1})->to(controller=>'Test1',);
  
  $routes->route('/callback')->over(access=>{auth=>1, role=>'admin'})
    ->to(cb=>sub {shift->render(format=>'txt', text=>'Admin role have access!')},);
}

my $t = Test::Mojo->new(__PACKAGE__);

#~ subtest 'foo' => sub {
  #~ my $routes = $config->{app_routes}($t);
  #~ warn $routes;
#~ };

$t->get_ok("/noauth")->status_is(200)
  ->content_like(qr/Welcome  Mojolicious::Plugin::RoutesAuthDBI/i);

$t->get_ok("/auth-only")->status_is(200)
  ->content_like(qr/Please sign in/i);

$t->get_ok("/authenticated")->status_is(404);
  #~ ->content_like(qr/Please sign in/i);

$t->get_ok("/$config->{prefix}/sign/in/$config->{admin_user}/$config->{admin_pass}")->status_is(302)
  ->${ \$config->{location_is} }("/$config->{prefix}");

$t->get_ok("/$config->{prefix}")->status_is(200)
  ->content_like(qr/You are signed as/i);

$t->get_ok("/auth-only")->status_is(200)
  ->content_like(qr/Welcome  Mojolicious::Plugin::RoutesAuthDBI/i);

$t->get_ok("/authenticated")->status_is(200)
  ->content_like(qr/Welcome  Mojolicious::Plugin::RoutesAuthDBI/i);

$t->get_ok("/test1/test1")->status_is(200)
  ->content_like(qr/test1\.+ok/i);

$t->get_ok("/test1")->status_is(200)
  ->content_like(qr/test1\.+ok/i);

$t->get_ok("/callback")->status_is(200)
  ->content_like(qr/Admin role have access/i);

done_testing();
