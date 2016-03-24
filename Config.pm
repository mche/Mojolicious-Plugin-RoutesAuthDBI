
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
	mojo_hooks=>{
		before_dispatch => sub {1;},
	},
	# Хазы
	#~ mojo_has => [# упорядоченные пары можно hash
		#~ foo=>sub {my $app = shift; },
	#~ ],
	mojo_secret => rand,
	#!!! пустой has dbh=>sub{{};}; в startup !!!
	dbh=>{# dsn, user, passwd
		'main'=>{
			connect=>["DBI:Pg:dbname=postgres;", "guest", undef, {# DBI->connect
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
			sth=>{now=>"select now();"},# prepared sth
		}
	},
	#!!! пустой has sth=>sub{{};}; в startup !!!
	sth => {# prepared sth
		main=>{now=>"select now();"},
	},
};


