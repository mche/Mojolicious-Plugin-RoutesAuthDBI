package Mojolicious::RendererDebug;
use Mojo::Base 'Mojolicious::Renderer';

#~ sub new {
  #~ shift->SUPER::new(@_);
  
#~ }

sub render {
  my ($self, $c, $args) = (shift, @_);
  #~ my $tx = $c->tx;# Prepare transaction
  $c->app->log->debug($c->dumper($c->req));
  $c->app->log->debug($c->dumper($c->req->params->to_hash));
  $self->SUPER::render(@_);
}

1;