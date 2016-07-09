
=pod
Главный Конфиг сервиса
=cut


{
  'Проект'=>'Тест плугинов',
  # установка лог файла раньше установки режима, поэтому всегда log/development.log!!!!
  #mojo_mode=>$ENV{PLACK_ENV} ? 'production' : 'development', #  production $ENV{ MOJO_MODE}
  mojo_mode=> 'development',
  # mode принудительно production если увидит $ENV{PLACK_ENV}
  mojo_log_level => 'debug',#$ENV{PLACK_ENV} ? 'error' : 'debug', 
  mojo_plugins=>[ # map $self->plugin($_)
      [charset => { charset => 'UTF-8' }, ],
      ['EDumper', helper =>'dumper'],
      ['RoutesAuthDBI',
          dbh=>sub{ shift->dbh->{'main'}},
          auth=>{current_user_fn=>'auth_user'},
          #~ access=> { },
          admin=>{prefix=>'myadmin', trust00=>'fooobaaar'},
          template => {schema => 'test3', tables=>{profiles=>'профили'},},
      ],
  ],
  mojo_session => {cookie_name => 'ELK'},
  # Хуки
  #~ mojo_hooks=>{
    #~ before_dispatch => sub {1;},
  #~ },
  # Хазы
  #~ mojo_has => {
    #~ foo=>sub {my $app = shift; },
  #~ },
  mojo_secrets => ['true 123 test-app',],
  #!!! пустой has dbh=>sub{{};}; в app !!!
  dbh=>{# dsn, user, passwd
    'main'=>{
      connect=>["DBI:Pg:dbname=test;", "guest", undef, {# DBI->connect
        ShowErrorStatement => 1,
        AutoCommit => 1,
        RaiseError => 1,
        PrintError => 0, 
        pg_enable_utf8 => 1,
        #mysql_enable_utf8 => 1,
        #mysql_auto_reconnect=>1,
        #~ AutoInactiveDestroy => 1,
      }],
      do=>['set  datestyle to "ISO, DMY";',],
      sth=>{# prepared sth
          'table.columns'=><<SQL,
select * 
from information_schema.columns
where
  table_catalog='test'
  and table_schema=? --'public'
  and table_name=? --'routes'
;


SQL
        
        },
      
    }
  },
  #!!! пустой has sth=>sub{{};}; в app !!!
  sth => { main=>{},},# prepared sth
#~ now=>"select now();"
  namespaces => [],
  routes => [
  [
    route=>'/callback',
    over=>{access=>{auth=>1, role=>'admin'}},
    to=>sub {shift->render(format=>'txt', text=>'You have access!')},
    name=>'foo',#'install#manual', namespace000=>'Mojolicious::Plugin::RoutesAuthDBI',
  ],[
    route=>'/check-auth',
    over=>{access=>sub {my ($user, $route, $c, $captures, $args) = @_; return $user;}},
    to=>{cb=>sub {my $c =shift; $c->render(format=>'txt', text=>"Hi @{[$c->auth_user->{login}]}! You have access!");}},
  ],[
    route=>'/routes',
    to=>{cb=>sub {my $c =shift; $c->render(format=>'txt', text=>$c->dumper($c->match->endpoint));}},
    name=>'app routes',
  ],[
    route=>'/man',
    over=>{access=>{auth=>0,}},
    to=>['install#manual', namespace=>'Mojolicious::Plugin::RoutesAuthDBI',],#
  ],[
    route=>'/schema/:schema',
    over=>{access=>{auth=>0,}},
    to=>['db#schema', namespace=>'Mojolicious::Plugin::RoutesAuthDBI',],#
  ],[
    route=>'/test1',
    over=>{access=>{auth=>1,}},
    to=>'test#test1',
  ],[
    route=>'/test5/:action',
    to=>{controller=>'Test'},
  ],
  ],
};


