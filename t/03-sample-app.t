use Mojo::Base 'Mojolicious';
use Test::More;
use Test::Mojo;

sub startup {
  shift->routes->route('/app')
    ->to('install#test_app', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');
}

my $t = Test::Mojo->new(__PACKAGE__);

$t->get_ok('/app')
  ->status_is(200)
  #~ ->content_like(qr/table\s+(?:IF NOT EXISTS)?\s*"тестовая схема 156"\."связи"/i)
  #~ ->content_like(qr/table\s+(?:IF NOT EXISTS)?\s*"тестовая схема 156"\."профили"/i)
  #~ ->content_like(qr/SEQUENCE\s+"public"."id 156"/i)
  #~ ->content_like(qr/table\s+(?:IF NOT EXISTS)?\s*"тестовая схема 156"\."oauth2.providers"/i)
  #~ ->content_like(qr/table\s+(?:IF NOT EXISTS)?\s*"тестовая схема 156"\."oauth2.users"/i)
  #~ ->content_like(qr/table\s+(?:IF NOT EXISTS)?\s*"тестовая схема 156"\."роли доступа"/i)
  #~ ->content_like(qr/table\s+(?:IF NOT EXISTS)?\s*"тестовая схема 156"\."маршруты"/i)
  ;

warn $t->tx->res->text;

done_testing();