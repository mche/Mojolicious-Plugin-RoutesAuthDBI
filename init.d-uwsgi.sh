#!/bin/bash

# Use uwsgi to run psgi web apps.
# !!! Запускать от простого пользователя
# для которого установлен perlbrew
# su - <user> -c "/home/<user>/service1/<this bash script>.sh start"

# http://perlbrew.pl/Perlbrew-In-Shell-Scripts.html
# perlbrew info
#~ export PERLBREW_ROOT=~/perl5/perlbrew
#~ export PERLBREW_HOME=~/.perlbrew
#~ source ${PERLBREW_ROOT}/etc/bashrc
#perlbrew use perl-5.16.3

# mojo generate app Service1
SERVICE_ROOT=~/api.dropboxapi.com
SERVICE_SCRIPT="$SERVICE_ROOT/test-app.pl"
#~ OWNER=guest # su
#~ GROUP=guest
NAME=uwsgi
DESC=uwsgi

# uWSGI собирать при соответсвующем Перле!!!
# perlbrew use perl-5.16.2
# $ curl http://uwsgi.it/install | bash -s psgi ~/uwsgi-perl-v5.16.2
DAEMON=~/uwsgi
LOG="$SERVICE_ROOT/log/$NAME.log"
#~ LOG="/dev/null"

#LOG="$SERVICE_ROOT/log/development.log"
PID_FILE="$SERVICE_ROOT/$NAME.pid"
SOCK="$SERVICE_ROOT/uwsgi.sock"
NUM_SOCK=1 # сверь с uwsgi_pass/upstream nginx.conf, циферка в названии файла сокета в конце
THIS=$0
ACTION=$1
shift
DAEMON_OPTS="--psgi $SERVICE_SCRIPT --uwsgi-socket=$SOCK --master  --pidfile=$PID_FILE --daemonize=$LOG"
#  --enable-threads --processes=5
# --http-websockets
#--declare-option '$@' --uid=$OWNER --gid=$GROUP --uwsgi-socket=$SOCK.{1..$NUM_SOCK}
echo "CHECK COMMAND: " $DAEMON $DAEMON_OPTS
#~ %v	the vassals directory (pwd)
#~ http://uwsgi-docs.readthedocs.org/en/latest/ConfigLogic.html
#~ http://uwsgi-docs.readthedocs.org/en/latest/Configuration.html
#~ [13:27] <GrahamDumpleton> guest-quest: If you don't understand what it is, use --single-interpreter
#~ [13:27] <GrahamDumpleton> It is safer to use single interpreter.

test -x $DAEMON || exit 0

# Include uwsgi defaults if available
if [ -f /etc/default/uwsgi ] ; then
	. /etc/default/uwsgi
fi

set -e

get_pid() {
    if [ -f $PID_FILE ]; then
        echo `cat $PID_FILE`
    fi
}   


case $ACTION in # был shift!!!
  start)
	echo -n "Starting $DAEMON... "
        PID=$(get_pid)
        if [ -z "$PID" ]; then
            [ -f $PID_FILE ] && rm -f $PID_FILE
            touch $PID_FILE
	    touch $LOG
            #~ chown $OWNER:$GROUP $PID_FILE
	    #~ su - $OWNER -pc "$DAEMON $DAEMON_OPTS"
	    $DAEMON $DAEMON_OPTS
	    echo "OK."
	else 
	    echo "Its running? Found PID_FILE=[$PID_FILE]. Check (ps ax | grep \"$DAEMON\" | grep $PID) and then (rm '$PID_FILE')"
	    ps=$(ps ax | grep "$DAEMON" | grep $PID)
	    # echo "123 $ps"
	    if [ -z "$ps" ]; then
		# ps=$(ps ax | grep $PID)
		echo "Проверить для rm"
		
		exit
	    else
		echo "Found process:"
		echo "$ps"
	    fi
	    
        fi

	;;
  stop)
	echo -n "Stopping $DAEMON... "
        PID=$(get_pid)
        [ ! -z "$PID" ] && kill -s 3 $PID &> /dev/null
        if [ $? -gt 0 ]; then
            echo "was not running" 
            exit 1
        else 
	    echo "OK."
            rm -f $PID_FILE &> /dev/null
	    for s in $(seq $NUM_SOCK);
		    do
		    rm -f "$SOCK.$s" &> /dev/null
	    done
	    
        fi
	;;
  reload)
        echo "Reloading $DAEMON..." 
        PID=$(get_pid)
        [ ! -z "$PID" ] && kill -s 1 $PID # &> /dev/null
        if [ $? -gt 0 ]; then
            echo "was not running" 
            exit 1
        else 
	    echo "OK."
        fi
	;;
  force-reload)
        echo "Reloading $DAEMON..." 
        PID=$(get_pid)
        [ ! -z "$PID" ] && kill -s 15 $PID &> /dev/null
        if [ $? -gt 0 ]; then
            echo "was not running" 
            exit 1
        else 
	    echo "OK."
        fi
        ;;
  restart)
        $0 stop
        sleep 2
        $0 start
	;;
  status) 
	# инфа кидается в лог $LOG
	killall -10 $DAEMON
	tail -n 100 $LOG
	;;
      *)  
	    echo "Usage: $THIS {start|stop|restart|reload|force-reload|status} [options pass to app -- not work :(]" >&2
	    exit 1
	    ;;
    esac
    exit 0
