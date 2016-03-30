
=pod
Главный Конфиг сервиса, различные опции для главного модуля
В него сливаются все отдельные конфиги
Его имя жестко зашито в app
=cut

#use strict;# Plugin::Config добавляет use Mojo::Base -strict
#~ use utf8;

{
	'Проект'=>'Тест плугинов',
	# установка лог файла раньше установки режима, поэтому всегда log/development.log!!!!
	#mojo_mode=>$ENV{PLACK_ENV} ? 'production' : 'development', #  production $ENV{ MOJO_MODE}
	mojo_mode=> 'development',
	# mode принудительно production если увидит $ENV{PLACK_ENV}
	mojo_log_level => 'debug',#$ENV{PLACK_ENV} ? 'error' : 'debug', 
	mojo_plugins=>[ # map $self->plugin($_)
			#~ ['PODRenderer'], # Documentation browser under "/perldoc"
			[charset => { charset => 'UTF-8' }, ],
			#[PoweredBy => {name => "Perl $^V Web Service"}],
			#~ [ConfigRoutes => {file=>"ConfigRoutes.pm",},],#"$FindBin::Bin/ConfigRoutes.pm",
			 #~ ['ConfigApply'],
			#~ ['HeaderCondition'],
			#~ ['ParamsArray'],
	],
	# Хуки
	#~ mojo_hooks=>{
		#~ before_dispatch => sub {1;},
	#~ },
	# Хазы (не катят в Plugin::ApplyConfig)
	#~ mojo_has => {
		#~ foo=>sub {my $app = shift; },
	#~ },
	mojo_secrets => ['хороший 123 test-app',],
	#!!! пустой has dbh=>sub{{};}; в app !!!
	dbh=>{# dsn, user, passwd
		'main'=>{
			connect=>["DBI:Pg:dbname=test;", "guest", undef, {# DBI->connect
				ShowErrorStatement => 1,
				AutoCommit => 1,
				RaiseError => 1,
				PrintError => 1, 
				pg_enable_utf8 => 1,
				#mysql_enable_utf8 => 1,
				#mysql_auto_reconnect=>1,
				#~ AutoInactiveDestroy => 1,
			}],
			do=>['set  datestyle to "ISO, DMY";',],
			#~ sth=>{now=>"select now();"},# prepared sth
		}
	},
	#!!! пустой has sth=>sub{{};}; в app !!!
	sth => { main=>{},},# prepared sth

};


