use Mojo::Base 'Mojolicious';


# This method will run once at server start
sub startup {# 
  my $app = shift;
  my $r = $app->routes;
  $r->route('/')->to(cb=>sub {my $c =shift; die; $c->render(format=>'txt', text=>"One\n");})
  #~ $r->route('/')
  ->to(cb=>sub {my $c =shift; die; $c->render(format=>'txt', text=>"Two\n");});
  
}

__PACKAGE__->new()->start();