#~ use Mojo::Util qw(dumper);

#~ $app->helper(dumper => sub { shift; dumper @_ });

#~ sub decode {
  #~ my ($encoding, $bytes) = @_;
  #~ return undef
    #~ unless eval { $bytes = _encoding($encoding)->decode("$bytes", 1); 1 };
  #~ return $bytes;
#~ }

#~ my $chars = decode 'UTF-8', $bytes;
#~ Decode bytes to characters, or return undef if decoding failed.

use utf8;
use Data::Dumper;
use Encode qw(encode);
$Data::Dumper::Useqq = 0;

#~ { no warnings 'redefine';
    sub Data::Dumper::qquote {
        my $s = shift;
        return "'$s'";
    }
#~ }

my $str = {1, "abc роллд xyz"};

#~ binmode STDOUT, ':encoding(UTF-8)';
print encode 'utf8', Dumper $str;

__END__

use Data::Dumper;
#~ $Data::Dumper::Useqq = 1;
#~ use Encode qw(encode decode);

#~ BEGIN {
#~ sub Data::Dumper::qquote {
    #~ my $s = shift;
    #~ return "'$s'";
#~ }

#~ }

sub dumper {
  Data::Dumper->new([@_])->Indent(1)->Sortkeys(1)->Terse(1)->Useqq(0)->Dump;
}

#~ binmode STDOUT, ':encoding(UTF-8)';

$a = dumper {'фвавэ'=>'куднрещз', 'крее'=>{'кркеер'=>'апренерен',}};

print $a, 

__END__
#~ sub encode { _encoding($_[0])->encode("$_[1]") }


use Mojo::Base -strict;
#~ use Mojo::Util qw(dumper);
use Data::Recursive::Encode;
use Data::Dumper;#::AutoEncode;

sub eDumper {
    Data::Dumper->new([map Data::Recursive::Encode->encode('utf8', $_), @_])->Indent(1)->Sortkeys(1)->Terse(1)->Useqq(0)->Dump;

  }

print eDumper({ 'варивпы' => 'おでん' }, 'вася');
__END__
#~ 
use utf8;
use utf8;
    use Data::Dumper::AutoEncode;

    my $foo = +{ 'варивпы' => 'おでん' };

    print eDumper($foo);






