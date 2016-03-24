package Mojolicious::Plugin::ConfigApply;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
  my ($self, $app, $arg) = @_;
  my $conf = $app->config($arg)->config;

  $app->mode($conf->{'mojo_mode'} || $conf->{'mojo'}{'mode'} || 'development'); # Файл лога уже не переключишь
  $app->log->level( $conf->{'mojo_log_level'} || $conf->{'mojo'}{'log_level'} || 'debug');
  
  # Плугины из конфига
  map {$app->plugin(@$_);} @{$conf->{'mojo_plugins'} || $conf->{'mojo'}{'plugins'} };
  # хазы тут не пойдут
  $self->_dbh($app);
  $self->_sth($app);
  $self->_hooks($app);
  
  $app->secrets($conf->{'mojo_secret'} || $conf->{'mojo_secrets'} || $conf->{'mojo'}{'secret'} || $conf->{'mojo'}{'secrets'} || rand);


}

sub _dbh {# обрабатывает dbh конфига
  my $self = shift;
  my $app = shift;
  my $conf = $app->config;
  my $c_dbh = $conf->{dbh};
  return unless $c_dbh && keys %$c_dbh;
  my $dbh = $app->dbh;
  my $sth = $app->sth;
  require DBI;
  
  while (my ($db, $opt) = each %$c_dbh) {
    $dbh->{$db} ||= DBI->connect(@{$opt->{connect}});
    $app->log->debug("Соединился с базой [$opt->{connect}[0]]");
    
    map {
      $dbh->{$db}->do($_);
    } @{$opt->{do}} if $opt->{do};
    
    while (my ($st, $sql) = each %{$opt->{sth}}) {
      $sth->{$db}{$st} = $dbh->{$db}->prepare($sql);# $self->{sth}{main}{...}
      $app->log->debug("Подготовился запрос [app->sth->{$db}{$st}]");
    }
  }
  $dbh;
  
}

sub _sth {# обрабатывает sth конфига
  my $self = shift;
  my $app = shift;
  my $conf = $app->config;
  my $c_sth = $conf->{sth};
  return unless $c_sth && keys %$c_sth;
  my $dbh = $app->dbh;
  my $sth = $app->sth;
  
  while (my ($db, $h) = each %$c_sth) {
    while (my ($st, $sql) = each %$h) {
      $sth->{$db}{$st} = $dbh->{$db}->prepare($sql);# $self->{sth}{main}{...}
      $app->log->debug("Подготовился запрос [app->sth->{$db}{$st}]");
    }
  }
  $sth;
}

  # Хуки из конфига
sub _hooks {
  my $self = shift;
  my $app = shift;
  my $conf = $app->config;
  my $hooks = $conf->{'mojo_hooks'} || $conf->{'mojo'}{'hooks'};
  return unless $hooks;
  while (my ($name, $sub) = each %$hooks) {
  #~ map {
    $app->hook($name => $sub);
    $app->log->debug("Applied hook [$name] from config");
  }

}
1;