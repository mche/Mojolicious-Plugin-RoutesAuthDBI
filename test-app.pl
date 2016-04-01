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
  #~ $app->plugin('RoutesAuthDBI', dbh=>$app->dbh->{'main'}, auth=>{current_user_fn=>'auth_user'}, admin=>{prefix=>'myadmin', trust=>'fooobaaar',},);
  my $r = $app->routes;
  $r->route('/install')->to('Admin#install', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');
  $r->route('/schema')->to('Admin#schema', namespace=>'Mojolicious::Plugin::RoutesAuthDBI');
}

__PACKAGE__->new()->start();