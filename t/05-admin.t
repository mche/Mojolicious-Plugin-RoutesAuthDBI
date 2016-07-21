use Mojo::Base 'Mojolicious';
use Test::More;
use Test::Mojo;
use DBI;

plan skip_all => 'set env TEST_CONN_PG="DBI:Pg:dbname=<db>/<pg_user>/<passwd>" to enable this test'
  unless $ENV{TEST_CONN_PG};

has dbh => sub { DBI->connect(split m|[/]|, $ENV{TEST_CONN_PG}) };

my $config = do 't/config.pm';

sub startup {
  my $app = shift;
  $app->plugin('RoutesAuthDBI',
    auth=>{current_user_fn=>'auth_user'},
    admin=>{prefix=>$config->{prefix}, trust=>$config->{trust},},
    template=>$config,
  );
}

my $t = Test::Mojo->new(__PACKAGE__);

subtest 'routes' => sub {
  my $stdout;
  local *STDOUT;
  open(STDOUT, ">", \$stdout);
  $t->app->commands->run('routes');
  like $stdout, qr/\/$config->{prefix}\/$config->{trust}\/admin\/new\/:login\/:pass/, 'routes';
  like $stdout, qr/signin stash/, 'sign in route';
};


$t->get_ok("/$config->{prefix}")->status_is(200)
  ->content_like(qr/Deny access at auth step/i);

$t->get_ok("/$config->{prefix}/sign/in/$config->{admin_user}/$config->{admin_pass}")->status_is(302)
  ->${ \$config->{location_is} }("/$config->{prefix}");

$t->get_ok("/$config->{prefix}")->status_is(200)
  ->content_like(qr/You are signed as/i);

$t->get_ok("/$config->{prefix}/users")->status_is(200)
  ->content_like(qr/Profiles\(1\)/i);

$t->get_ok("/$config->{prefix}/user/new/$config->{user1}/$config->{pass1}")->status_is(200)
  ->content_like(qr/Success sign up new profile/i);

$t->get_ok("/$config->{prefix}/user/new?login=$config->{user2}&pass=$config->{pass2}")->status_is(200)
  ->content_like(qr/Success sign up new profile/i);

$t->get_ok("/$config->{prefix}/users")->status_is(200)
  ->content_like(qr/Profiles\(3\)/i);

$t->get_ok("/$config->{prefix}/users/admin")->status_is(200)
  ->content_like(qr/Profile\/users\(1\) by role \[admin\]/i);

$t->get_ok("/$config->{prefix}/role/new/$config->{role}")->status_is(200)
  ->content_like(qr/Success created role/i);

$t->get_ok("/$config->{prefix}/role/$config->{role}/$config->{user1}")->status_is(200)
  ->content_like(qr/Success assign ROLE\[$config->{role}\] -> USER \[bless/i);

$t->get_ok("/$config->{prefix}/users/$config->{role}")->status_is(200)
  ->content_like(qr/Profile\/users\(1\) by role \[$config->{role}\]/i);

$t->get_ok("/$config->{prefix}/roles/$config->{user1}")->status_is(200)
  ->content_like(qr/List of profile\/login roles \(1\)/i);

$t->get_ok("/$config->{prefix}/roles")->status_is(200)
  ->content_like(qr/ROLES\(2\)/i);

$t->get_ok("/$config->{prefix}/role/dsbl/$config->{role}")->status_is(200)
  ->content_like(qr/Success disable role/i);

$t->get_ok("/$config->{prefix}/role/enbl/$config->{role}")->status_is(200)
  ->content_like(qr/Success enable role/i);

$t->get_ok("/$config->{prefix}/role/del/$config->{role}/$config->{user1}")->status_is(200)
  ->content_like(qr/Success delete ref ROLE\[$config->{role}\] -> USER\[bless/i);

$t->get_ok("/$config->{prefix}/users/$config->{role}")->status_is(200)
  ->content_like(qr/Profile\/users\(0\) by role \[$config->{role}\]/i);

$t->get_ok("/$config->{prefix}/roles/$config->{user1}")->status_is(200)
  ->content_like(qr/List of profile\/login roles \(0\)/i);

done_testing();
