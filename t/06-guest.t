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
  $r->get('/guest/new')->to("$pkg#create");
}

sub create {
  my $c = shift;
  $c->render(text=>'ok');
  
}

my $t = Test::Mojo->new($pkg);

$t->get_ok("/guest/new")->status_is(200)
  #~ ->content_like(qr/Deny access at auth step/i)
  ;

#~ $t->get_ok("/$config->{prefix}/$config->{trust}/$config->{role_admin}/new/$config->{admin_user}/$config->{admin_pass}")->status_is(200)
  #~ ->content_like(qr/Success sign up new trust-admin-user/i);
  #~ ->content_like(qr/$config->{role_admin}-000/i);


done_testing();
