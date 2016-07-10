package Mojolicious::Plugin::RoutesAuthDBI::Util;
use Mojo::Base -base;
use Exporter 'import';
use Mojo::JSON qw(decode_json encode_json);
use Encode qw(encode decode);
use Mojo::Loader;

our @EXPORT_OK = qw(json_enc json_dec load_class);

sub json_enc {
  decode('utf-8', encode_json(shift));
  
}

sub json_dec {
  decode_json(encode('utf-8', shift));
}

sub load_class {
  my $class;
  if (@_ == 1 && ! ref $_[0]) {$class = shift}
  else {
    my $conf = ref $_[0] ? shift : {@_};
    $class  = join '::', $conf->{namespace} ? ($conf->{namespace}) : (), $conf->{module} || $conf->{controller} || $conf->{package};
  }
  
  
  my $e; $e = Mojo::Loader::load_class($class)# success undef
    and warn('None load_class[$class]: ', $e)
    and return undef;
  return $class;
}

1;