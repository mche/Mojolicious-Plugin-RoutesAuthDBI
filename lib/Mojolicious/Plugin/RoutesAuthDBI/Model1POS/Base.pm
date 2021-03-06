package Mojolicious::Plugin::RoutesAuthDBI::Model::Base;
use Mojo::Base -base;
use Carp 'croak';
use DBIx::POS::Template;

my %DICT_CACHE = ();# для каждого пакета/модуля

has [qw(dbh dict template)];

#init once
sub singleton {
  state $singleton = shift->SUPER::new(@_);
}

# child model
sub new {
  my $self = ref $_[0] ? shift : shift->SUPER::new(@_);
  my $singleton = $self->singleton;
  
  $self->dbh($singleton->dbh)
    unless $self->dbh;
    
  $self->template($singleton->template)
    unless $self->template;
  
  my $pkg = ref $self;
  
  $self->dict( $DICT_CACHE{$pkg} ||= DBIx::POS::Template->new($pkg, template=>$self->template) )
    unless $self->dict;
  $self;
}

sub sth {
  my $self = shift;
  my $name = shift;
  my $dict = $self->dict;
  my $st = $dict->{$name}
    or croak "No such name[$name] in SQL dict! @{[ join ':', keys %$dict  ]}";
  #~ my %arg = @_;
  my $sql = $st->template(@_).sprintf("\n--Statement name[%s]", $st->name); # ->template(%$template ? %arg ? %{merge($template, \%arg)} : %$template : %arg)
  my $param = $st->param;
  
  my $sth;

  #~ local $dbh->{TraceLevel} = "3|DBD";
  
  if ($param && $param->{cached}) {
    $sth = $self->dbh->prepare_cached($sql);
    #~ warn "ST cached: ", $sth->{pg_prepare_name};
  } else {
    $sth = $self->dbh->prepare($sql);
  }
  
  return $sth;
  
}

=pod

=encoding utf8

Доброго всем

=head1 Mojolicious::Plugin::RoutesAuthDBI::Model::Base

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 SINOPSYS

Always singleton for process.

Init once in plugin register with dbh and (optional) template defaults only:

  use Mojolicious::Plugin::RoutesAuthDBI::Model::Base;
  Mojolicious::Plugin::RoutesAuthDBI::Model::Base->singleton(dbh=>$dbh, template=>$t);

In child model must define SQL dict:

  package Model::Foo;
  use Mojo::Base 'Mojolicious::Plugin::RoutesAuthDBI::Model::Base';
  
  sub new {
    state $self = shift->SUPER::new(@_);
  }
  
  sub foo {
    my $self = ref $_[0] ? shift : shift->new;
    $self->dbh->selectrow_hashref($self->sth('foo', where => 'where id=?',), undef, (shift));
  }
  
  =pod
  
  =name foo

  =desc test of my foo

  =param
  
    # Some arbitrary parameters as perl code (eval)
    {
        cache=>1, # will be prepare_cached
    }

  =sql

    select * from foo
    {% $where %}
    ;

In controller:

  ...
  has model => sub {require Model::Foo; Model::Foo->new;};
  
  sub actionFoo {
    my $c = shift;
    my $foo = $c->model->foo($c->param('id'));
    ...
  
  }

=head1 AUTHOR

Михаил Че (Mikhail Che), C<< <mche[-at-]cpan.org> >>

=head1 BUGS / CONTRIBUTING

Please report any bugs or feature requests at L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/issues>. Pull requests also welcome.

=head1 COPYRIGHT

Copyright 2016 Mikhail Che.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;