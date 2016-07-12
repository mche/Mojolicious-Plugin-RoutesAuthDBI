use Mojo::Base 'Mojolicious';
use Test::More;
use Test::Mojo;
use DBI;

plan skip_all => 'set env TEST_CONN_PG="DBI:Pg:dbname=<db>/<pg_user>/<passwd>" to enable this test'
  unless $ENV{TEST_CONN_PG};

has dbh => sub { DBI->connect(split m|[/]|, $ENV{TEST_CONN_PG})};

sub startup {
  my $app = shift;
  $app->plugin('RoutesAuthDBI',
    auth=>{current_user_fn=>'auth_user'},
    admin=>{prefix=>'testadmin', trust=>'foootestbaaar',},
  );
}

my $t = Test::Mojo->new(__PACKAGE__);

require Mojolicious::Command::routes;
my $routes = Mojolicious::Command::routes->new;
warn $routes->run;

#~ $t->get_ok('/man')->status_is(200)
  #~ ->content_like(qr/system ready!/);

done_testing();