use Mojo::Base 'Mojolicious';
use Test::More;
use Test::Mojo;
use DBI;

plan skip_all => 'set env TEST_CONN_PG="DBI:Pg:dbname=<db>/<pg_user>/<passwd>" to enable this test'
  unless $ENV{TEST_CONN_PG};

has dbh => sub { DBI->connect(split m|[/]|, $ENV{TEST_CONN_PG}) };

my $prefix = 'testadmin';
my $trust = 'footrust';

sub startup {
  my $app = shift;
  $app->plugin('RoutesAuthDBI',
    auth=>{current_user_fn=>'auth_user'},
    admin=>{prefix=>$prefix, trust=>$trust,},
    template=>{schema=>"тестовая схема 156",  sequence=>'"public"."id 156"', tables=>{routes=>'маршруты', profiles=>'профили', roles=>'роли доступа', refs=>'связи', oauth_sites=>'oauth2.providers', oauth_users=>'oauth2.users',}},
  );
}

my $t = Test::Mojo->new(__PACKAGE__);

subtest 'routes' => sub {
  my $stdout;
  local *STDOUT;
  open(STDOUT, ">", \$stdout);
  $t->app->commands->run('routes');
  like $stdout, qr/\/$prefix\/$trust\/admin\/new\/:login\/:pass/, 'routes';
};


$t->get_ok("/$prefix/$trust/admin/new/m3/секрет")->status_is(200)
  ->content_like(qr/Success sign up new trust-admin-user/i);

$t->get_ok("/$prefix")->status_is(200)
  ->content_like(qr/Deny access at auth step/i);

my $location_is = sub {
  my ($t, $value, $desc) = @_;
  $desc ||= "Location: $value";
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  return $t->success(is($t->tx->res->headers->location, $value, $desc));
};

$t->get_ok("/$prefix/sign/in/m3/секрет")->status_is(302)
  ->$location_is("/$prefix");
  #~ ->content_like(qr/Deny access at auth step/i);

$t->get_ok("/$prefix")->status_is(200)
  ->content_like(qr/You are signed as/i);


done_testing();
