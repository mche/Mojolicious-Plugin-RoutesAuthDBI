use strict;
use utf8::all;
use lib './lib';
use DBIx::POS::Template;

# separate object
my $pos = DBIx::POS::Template->instance(__FILE__, enc=>'utf8');
my $pos2 = DBIx::POS::Template->new('./lib/Mojolicious::Plugin::RoutesAuthDBI::POS::Pg', enc=>'utf8');

print $pos->{'тест'}->template(join => $pos2->{'тест'}.'', where => "bar = ?"), "\n";
print $pos->template('тест', join => $pos2->{'тест'}.'', where => "BaZ = ?"), "\n";
print keys %$pos2, "\n";

=pod

=encoding utf8

=name тест

=desc test the DBIx::POS::Template module

=param

Some arbitrary parameter

=sql

  select *
    from foo f
      join ({% $join %}) j on f.id=j.id
  where {% $where %}
  order by 1
  ;

=cut
