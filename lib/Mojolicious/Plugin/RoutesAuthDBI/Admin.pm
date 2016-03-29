package Admin;
use Mojo::Base 'Mojolicious::Controller';

sub index {
  my $c = shift;
  
  #~ $c->render(format=>'txt', text=>__PACKAGE__ . " At home!!! ".$c->dumper( $c->session('auth_data')));
  
  $c->render(format=>'txt', text=>__PACKAGE__ . " You are signed!!! ".$c->dumper( $c->auth_user))
    and return
    if $c->is_user_authenticated;
  
  $c->render(format=>'txt', text=>__PACKAGE__." You are not signed!!! To sign in/up go to /sign/<login>/<pass>");
}

sub sign {
  my $c = shift;
  
  $c->authenticate($c->stash('login'), $c->stash('pass'))
    and $c->render(format=>'txt', text=>__PACKAGE__ . " Successfull signed! ".$c->dumper( $c->auth_user))
    and return;
    
  
  $c->render(format=>'txt', text=>__PACKAGE__ . " Bad sign!!! Try again");
}

sub signout {
  my $c = shift;
  
  $c->logout;
  
  $c->render(format=>'txt', text=>__PACKAGE__ . "You are exited!!!");
  
}

sub init {
  my $c = shift;
  
  $c->render(format=>'txt', text=>__PACKAGE__ . " This is first run of plugin RoutesAuthDBI!!!");
  
}

1;