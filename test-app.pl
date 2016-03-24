#!/usr/bin/env perl
use Mojo::Base 'Mojolicious';

use FindBin;
use lib "$FindBin::Bin/lib";


# This method will run once at server start
sub startup {# 
  my $app = shift;
  $app->plugin(Config =>{file => 'Config.pm'});
  has dbh => sub { {}; };
  has sth => sub { {}; };
  $app->plugin('ConfigApply');
  $app->plugin('RoutesAuthDBI', dbh=>$app->dbh->{'main'});
  $app->routes->namespaces(['Controll']);
}

__PACKAGE__->new()->start();