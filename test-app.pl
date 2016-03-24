#!/usr/bin/env perl
use Mojo::Base 'Mojolicious';

use FindBin;
use lib "$FindBin::Bin/lib";



# This method will run once at server start
sub startup {# 
  my $app = shift;
  $app->plugin(Config =>{file => 'Config.pm'});# нельзя в new
  has dbh=>sub{{};};
  has sth=>sub{{};};
  $app->plugin('ConfigApply');
}

__PACKAGE__->new()->start();