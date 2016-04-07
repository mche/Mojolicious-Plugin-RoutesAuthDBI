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
    access=> {admin=>{prefix=>'myadmin', trust=>'fooobaaar'},},
  );
}



__PACKAGE__->new()->start();