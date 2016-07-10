use Mojo::Base -base;
use Hash::Merge qw( merge );
use Data::Dumper;
#~ &Hash::Merge::set_set_behavior('STORAGE_PRECEDENT');

has a => sub {
  {a=>\&a,};
  
};

my $s = __PACKAGE__->new;

my $a = {
          has=> $s->a->{a},
            'foo'    => 1,
        'bar'    => [ qw( a b e ) ],
        'querty' => { 'bob' => 'alice' },
      };
my $b = { 
            'foo'     => 2, 
            'bar'    => [ qw(c d) ],
            'querty' => { 'ted' => 'margeret' , bob=> 'bob'}, 
          };
 
my $c = merge( $b, $a );
#~ my $merge = Hash::Merge->new( );#'STORAGE_PRECEDENT00'
#~ print Dumper $merge->merge( \%b, \%a );
print Dumper $c;