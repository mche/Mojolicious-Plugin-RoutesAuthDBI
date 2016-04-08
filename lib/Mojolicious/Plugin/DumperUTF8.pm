package Mojolicious::Plugin::DumperUTF8;
use Mojo::Base 'Mojolicious::Plugin';
use Encode qw(decode);
use Data::Recursive::Encode;

our $VERSION = '0.00001';

sub register {
  my ($self, $app, $conf)  = @_;
  $conf->{enc} ||= 'utf8';
  $conf->{helper} ||= 'edumper';
  $app->helper($conf->{helper} => sub {
    shift;
    decode $conf->{enc}, Data::Dumper->new(Data::Recursive::Encode->encode($conf->{enc}, [@_]),)->Indent(1)->Sortkeys(1)->Terse(1)->Useqq(0)->Dump;
  });
  return $self;
}

#~ binmode STDOUT, ':encoding(UTF-8)';
#~ sub Data::Dumper::qquote {
    #~ my $s = shift;
    #~ return "'$s'";
#~ }



1;