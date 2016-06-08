package Mojolicious::Plugin::RoutesAuthDBI::Util;
use Mojo::Base -base;
use Exporter 'import';
use Mojo::JSON qw(decode_json encode_json);
use Encode qw(encode decode);

our @EXPORT_OK = qw(json_enc json_dec);

sub json_enc {
  decode('utf-8', encode_json(shift));
  
}

sub json_dec {
  decode_json(encode('utf-8', shift));
}



1;