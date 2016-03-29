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
  $app->plugin('RoutesAuthDBI', dbh=>$app->dbh->{'main'}, sth=>$app->sth->{'main'}, auth=>{current_user_fn=>'auth_user'}, admin=>1);
}

__PACKAGE__->new()->start();