package Mojolicious::Plugin::ConfigApply;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
  my ($self, $app, $arg) = @_;
  my $conf = $app->config($arg)->config;
  #~ $app->log->debug($app->dumper($conf));
  $app->log->level( $conf->{'mojo_log_level'} || $conf->{'mojo'}{'log_level'} || 'debug');
  # Плугины из конфига
  map {$app->plugin(@$_);} @{$conf->{'mojo_plugins'} || $conf->{'mojo'}{'plugins'} };
}
  has dbh => sub {# обрабатывает dbh этого конфига
    my $self = shift;# app
    my $config = $self->config;
    #~ $self->{dbh} ||= {};
    #~ $self->{sth} ||= {};
    #~ my $sth = $config->{sth};
    #~ my $dbh;
    map {
      my $db = $_;
      my $opt = $config->{dbh}{$_};
      #map {$opt->[3]{$_} = $config->{default_dbi_attr}{$_};} keys %{$config->{default_dbi_attr}} unless defined $opt->[3]{$_};# атрибуты
      $dbh->{$_} ||= DBI->connect(@{$opt->{connect}});
      $self->log->debug("Соединился с базой [$opt->{connect}[0]]");
      
      map {
        $dbh->{$db}->do($_);
      } @{$opt->{do}} if $opt->{do};
      
      map {
        my $sql = $opt->{sth}{$_};
        $sth->{$db}{$_} ||= $dbh->{$db}->prepare($sql);# $self->{sth}{main}{...}
        $self->log->debug("Подготовился запрос [app->sth->{$db}{$_}]");
      } keys %{$opt->{sth}} if $opt->{sth};
      
    } keys %{$config->{dbh}};
    
    $dbh;
  };

1;