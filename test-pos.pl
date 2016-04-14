#~ use Template;
use DBIx::POS;
use utf8;

#~ my $a = Template->new(foo=>'bar');
my $a = DBIx::POS->instance();#'lib/Mojolicious/Plugin/RoutesAuthDBI/POS/Pg.pm'

print keys %$a, "$a\n";

%$a = ();

#~ $a = DBIx::POS->instance('lib/Mojolicious/Plugin/RoutesAuthDBI/Install.pm');

$a->parse_from_file('lib/Mojolicious/Plugin/RoutesAuthDBI/Install.pm');
%b = (%$a);
%$a = ();

print map("[$_] ", keys %b), "$a\n";

