#!/usr/bin/env perl

# find ~/perl5/lib/ -type f -exec grep -Hni 'is not a controller' {} \;


package TestApp;
use Mojo::Base 'Mojolicious';


use FindBin;
use lib "$FindBin::Bin/lib";
#~ use Mojolicious::RendererDebug;

has dbh => sub { {}; };
has sth => sub { {}; };

#~ has renderer => sub { Mojolicious::RendererDebug->new };

# This method will run once at server start
sub startup {# 
  my $app = shift;
  $app->plugin(Config =>{file => 'Config.pm'});
  $app->plugin('ConfigApply');
  $app->plugin('RoutesAuthDBI',
    dbh=>$app->dbh->{'main'},
    auth=>{current_user_fn=>'auth_user'},
    access=> {},
    admin=>{prefix=>'myadmin', trust=>'fooobaaar'},
  );
  my $r = $app->routes;
  $r->route('/myadmin/foo')->over(access=>{auth=>1, role=>'admin'})->to(sub {shift->renderer(format=>'txt', text=>'You have assess!')})->name('foo');#'install#manual', namespace000=>'Mojolicious::Plugin::RoutesAuthDBI',
}



__PACKAGE__->new()->start();