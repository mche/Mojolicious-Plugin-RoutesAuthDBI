use Mojo::Base 'Mojolicious';

sub startup {
  my $app = shift;
  $app->helper('foo'=>sub {shift;});
  #~ say $app->can('foo');
  $app->routes->any('/')->to(cb=>sub {my $c =shift; $c->render(text=>$app->dumper($app->renderer->helpers))});
  
}

__PACKAGE__->new->start;