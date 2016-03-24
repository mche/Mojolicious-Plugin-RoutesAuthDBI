#!/usr/bin/env perl
use Mojo::Base 'Mojolicious';

use FindBin;
use lib "$FindBin::Bin/lib";

# This method will run once at server start
sub startup {# 
  my $self = shift;
  $self->plugin(Config =>{file => 'Config.pm'});# нельзя в new
  $self->plugin('ConfigApply'=>{1=>2});
}

__PACKAGE__->new()->start();