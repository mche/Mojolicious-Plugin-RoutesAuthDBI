package Template;
use base 'DBIx::POS';

sub new {
  my $self = shift->SUPER::new(@_);
  
}

sub end_input {
  my $self = shift;
  warn $info."\n";
  $self->SUPER::end_input(@_);
  
}

1;