package Mojolicious::Plugin::RoutesAuthDBI::POS::Actions;
use DBIx::POS::Template;
use Hash::Merge qw(merge);
use Mojolicious::Plugin::RoutesAuthDBI::Schema;

my $defaults = $Mojolicious::Plugin::RoutesAuthDBI::Schema::defaults;

sub new {
  my $class= shift;
  my %arg = @_;
  #~ $arg{template} = $arg{template} ? merge($arg{template}, $defaults) : $defaults;
  #~ $class->SUPER::new(__FILE__, %arg);
  DBIx::POS::Template->new(__FILE__, %arg);
}

=pod

=encoding utf8

=head3 Warn

B<POD ERRORS> here is normal because DBIx::POS::Template used.

=head1 Mojolicious::Plugin::RoutesAuthDBI::POS::Actions

¡ ¡ ¡ ALL GLORY TO GLORIA ! ! !

=head1 NAME

Mojolicious::Plugin::RoutesAuthDBI::POS::Actions - POS-dict for model Actions.

=head1 DB DESIGN DIAGRAM

See L<https://github.com/mche/Mojolicious-Plugin-RoutesAuthDBI/blob/master/Diagram.svg>

=head1 SYNOPSIS

    
    my $pos = Mojolicious::Plugin::RoutesAuthDBI::POS::Actions->new(template=>{tables=>{...}});
    
    my $sth = $dbh->prepare($pos->{'foo'});

=head1 Methods

One new()

=head2 new()

Input args for new:

=head3 template - hashref

Vars for template system of POS-statements.

=head1 SEE ALSO

L<DBIx::POS::Template>

=head1 SQL definitions

=head2 access action

=name access action

=desc

доступ к действию в контроллере (действие-каллбак - доступ проверяется по его ID)

=param

  {cached=>1}

=sql

  select count(r.*)
  from
    "{% $schema %}"."{% $tables{refs} %}" rc 
    join "{% $schema %}"."{% $tables{actions} %}" a on a.id=rc.id2
    join "{% $schema %}"."{% $tables{refs} %}" r on a.id=r.id1
    ---join "{% $schema %}"."{% $tables{roles} %}" o on o.id=r.id2
  where
    rc.id1=? ---controller id
    and a.action=?
    and r.id2=any(?) --- roles ids
    ---and coalesce(o.disable, 0::bit) <> 1::bit
  ;

=head2 actions

=name actions

=desc

Список действий

=sql

  select * from (
  select a.*, ac.controller_id, ac.controller
  from "{% $schema %}"."{% $tables{actions} %}" a
    left join (
      select a.id, c.id as controller_id, c.controller
      from "{% $schema %}"."{% $tables{actions} %}" a
        join "{% $schema %}"."{% $tables{refs} %}" r on a.id=r.id2
        join "{% $schema %}"."{% $tables{controllers} %}" c on c.id=r.id1
      ) ac on a.id=ac.id-- действия с контроллером
  ) as a
  {% $where %}

=head2 new action

=name new action

=desc 

=sql

  insert into "{% $schema %}"."{% $tables{actions} %}" (action, callback, descr)
  values (?,?,?)
  returning *;


=cut

1;