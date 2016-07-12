use Mojo::Base 'Mojolicious';
use Test::More;
use Test::Mojo;
use DBI;

plan skip_all => 'set env TEST_CONN_PG="DBI:Pg:dbname=<db>/<pg_user>/<passwd>" to enable this test'
  unless $ENV{TEST_CONN_PG};

has dbh => sub { DBI->connect(split m|[/]|, $ENV{TEST_CONN_PG})};

my $prefix = 'testadmin';
my $trust = 'footrust';

sub startup {
  my $app = shift;
  $app->plugin('RoutesAuthDBI',
    auth=>{current_user_fn=>'auth_user'},
    admin=>{prefix=>$prefix, trust=>$trust,},
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


#~ $t->get_ok('/man')->status_is(200)
  #~ ->content_like(qr/system ready!/);

done_testing();
