use Mojo::Base 'Mojolicious';

sub startup {
  my $app = shift;
  $app->routes->get('/')->to(cb=>sub {shift->render(text=>$app->dumper($app->plugins))});
  
}

__PACKAGE__->new->start;