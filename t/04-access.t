use Mojo::Base 'Mojolicious';
use Test::More;
use Test::Mojo;
use DBI;

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
}

my $t = Test::Mojo->new(__PACKAGE__);

#~ subtest 'foo' => sub {

#~ };


$t->get_ok("/$config->{prefix}/$config->{trust}/admin/new/$config->{admin_user}/$config->{admin_pass}")->status_is(200)
  ->content_like(qr/Success sign up new trust-admin-user/i);

done_testing();
