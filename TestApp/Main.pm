package TestApp::Main;
use Mojo::Base 'Mojolicious::Controller';

sub index {
  my $c = shift;
  
  #~ $c->render(format=>'txt', text=>__PACKAGE__ . " At home!!! ".$c->dumper( $c->session('auth_data')));
  
  $c->render(format=>'txt', text=>__PACKAGE__ . " At home!!! You are signed! ".$c->dumper( $c->auth_user))
    and return
    if $c->is_user_authenticated;
  
  $c->render(format=>'txt', text=>__PACKAGE__.": At home!!! You are not signed. To sign in/up go to /sign/<login>/<pass>");
}

sub sign {
  my $c = shift;
  
  $c->authenticate($c->stash('login'), $c->stash('pass'))
    and $c->render(format=>'txt', text=>__PACKAGE__ . " Successfull signed! ".$c->dumper( $c->auth_user))
    and return;
    
  
  $c->render(format=>'txt', text=>__PACKAGE__ . "Bad sign!!! Try again");
}

1;