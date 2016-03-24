#!/usr/bin/env perl
use Mojo::Base 'Mojolicious';

use FindBin;
use lib "$FindBin::Bin/lib";


# This method will run once at server start
sub startup {# 
  my $app = shift;
  #~ $app->log->debug($app->dumper($app->SUPER::startup(1,2,3)));
  $app->plugin(Config =>{file => 'Config.pm'});# нельзя в new
  has dbh=>sub{ {}; };
  has sth=>sub{ {}; };
  $app->plugin('ConfigApply');
  $app->plugin('RoutesAuthDBI', dbh=>$app->dbh->{'main'});
  $app->routes->namespaces(['Controll']);
}

__PACKAGE__->new()->start();