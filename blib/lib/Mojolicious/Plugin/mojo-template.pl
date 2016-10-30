use Mojo::Base -strict;
use Mojo::Loader qw(data_section);
use Mojo::Template;
use Mojo::Util qw(dumper);

# Different tags and line start
my $mt = Mojo::Template->new(vars => 1, tag_start=>'{%', tag_end=>'%}', line_start=>'$$',)->prepend('no strict qw(vars); no warnings qw(uninitialized);');
#~ $output = 

#~ say ref $mt;

my $sql = data_section __PACKAGE__;

say keys %$sql;
#~ say $sql->{'фу.бар.1'};
#~ say $mt->render($sql->{'фу.бар.1'}, 'test', {'таблица' => 'профили'});
#~ say $mt->render($sql->{'фу.бар.1/'}, {'бар'=> "<бар>",});

__DATA__
@@ фу.бар.1/cached=1

select *
from {%= $фу %} {%= $бар %}
;

@@ фу.бар.2
$$ my ($msg, $hash) = @_;
