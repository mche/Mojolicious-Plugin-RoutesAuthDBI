use Mojo::Base -strict;
{
  prefix => 'test-admin',
  trust =>'foo-trust',
  schema => 'тестовая схема 156',
  sequence => '"public"."seq 156"',
  tables=>{
    oauth_users=>'oauth2.users',
    oauth_sites=>'oauth2.providers',
    profiles=>'профили',
    refs=>'связи',
    roles=>'роли доступа',
    routes=>'маршруты',
  },
  admin_user => 'admin3',
  admin_pass => 'секрет',
  user1 => 'dora 156',
  pass1 => 's3cr3t',
  user2 => 'user 256',
  pass2 => 'pass 256',
  role => 'access 156',
  location_is => sub {
    my ($t, $value, $desc) = @_;
    $desc ||= "Location: $value";
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    return $t->success(is($t->tx->res->headers->location, $value, $desc));
  },
};