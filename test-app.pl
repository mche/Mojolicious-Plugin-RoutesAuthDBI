#!/usr/bin/env perl
# find ~/perl5/lib/ -type f -exec grep -Hni 'is not a controller' {} \;

package TestApp;
#~ use lib './lib';
use Mojo::Base::Che 'Mojolicious::Che', -lib, qw(lib t);

sub startup {# 
  my $app = shift;
  $app->plugin(Config =>{file => 'Config.pm'});
  $app->поехали();
}

__PACKAGE__->new()->start();