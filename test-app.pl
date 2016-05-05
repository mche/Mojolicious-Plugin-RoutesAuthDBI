#!/usr/bin/env perl

# find ~/perl5/lib/ -type f -exec grep -Hni 'is not a controller' {} \;


package TestApp;
use Mojo::Base 'Mojolicious';


use FindBin;
use lib "$FindBin::Bin/lib";


has dbh => sub { {}; };
has sth => sub { {}; };

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
    #~ schema=>'foo',
  );
  my $r = $app->routes;
  push @{ $r->namespaces() }, 'Mojolicious::Plugin::RoutesAuthDBI::Test',;
  
  $r->route('/callback')->over(access=>{auth=>1, role=>'admin'})->to(cb => sub {shift->render(format=>'txt', text=>'You have access!')})->name('foo');#'install#manual', namespace000=>'Mojolicious::Plugin::RoutesAuthDBI',
  $r->route('/check-auth')->over(access=>sub {my ($user, $route, $c, $captures, $args) = @_; return $user;})->to(cb=>sub {my $c =shift; $c->render(format=>'txt', text=>"Hi @{[$c->auth_user->{login}]}! You have access!");});
  $r->route('/routes')->to(cb=>sub {my $c =shift; $c->render(format=>'txt', text=>$c->dumper($c->match->endpoint));});
  $r->route('/man')->over(access=>{auth=>0,})->to('install#manual', namespace=>'Mojolicious::Plugin::RoutesAuthDBI',);#
  $r->route('/schema/:schema')->over(access=>{auth=>0,})->to('install#schema', namespace=>'Mojolicious::Plugin::RoutesAuthDBI',);#
  $r->route('/test1')->over(access=>{auth=>1,})->to('test#test1', );
  
}



__PACKAGE__->new()->start();