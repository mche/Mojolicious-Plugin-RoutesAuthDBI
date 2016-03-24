package Controll::Foo;
use Mojo::Base 'Mojolicious::Controller';

sub index {
  my $c = shift;
  $c->render(text=>__PACKAGE__." index!!!");
}

1;