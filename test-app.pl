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
  push @{ $r->namespaces() }, 'Mojolicious::Plugin::RoutesAuthDBI', 'Mojolicious::Plugin::RoutesAuthDBI::Test',;
  $r->route('/callback')->over(access=>{auth=>1, role=>'admin'})->to(cb => sub {shift->render(format=>'txt', text=>'You have access!')})->name('foo');#'install#manual', namespace000=>'Mojolicious::Plugin::RoutesAuthDBI',
  $r->route('/routes')->to(cb=>sub {my $c =shift; $c->render(format=>'txt', text=>$c->dumper($c->match->endpoint));});
  $r->route('/manual')->over(access=>{auth=>1,})->to('install#manual', namespace0=>0,)->name('man');#
  $r->route('/test1')->over(access=>{auth=>1,})->to('test#test1', namespace0=>0,);
  
}



__PACKAGE__->new()->start();