#!/usr/bin/env perl
# find ~/perl5/lib/ -type f -exec grep -Hni 'is not a controller' {} \;

package TestApp;
use Mojo::Base 'Mojolicious::Che';


use FindBin;
use lib "$FindBin::Bin/lib";


sub startup {# 
  my $app = shift;
  $app->plugin(Config =>{file => 'Config.pm'});
  $app->поехали();
}
__PACKAGE__->new()->start();