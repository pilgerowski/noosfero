#!/bin/bash

cmd="$@"
bundle install

echo "copying config/database.yml.pgsql -> config/database.yml"
cp /noosfero/config/database.yml.pgsql /noosfero/config/database.yml

function_postgres_ready() {
ruby << END
require 'pg'
begin
  PG.connect(dbname: "$POSTGRES_DB", user: "$POSTGRES_USER", password: "$POSTGRES_PASSWORD", host: "postgres")
rescue
  exit -1
else
  exit 0
end
END
}

until function_postgres_ready; do
  >&2 echo "POSTGRES IS UNAVAILABLE, SLEEP"
  sleep 1
done

echo "POSTGRES IS UP, CONTINUE"

echo "RUNNING MIGRATIONS"
if bundle exec rake db:exists; then
  bundle exec rake db:migrate
else
  bundle exec rake db:create
  bundle exec rake db:schema:load
  /noosfero/script/sample-data
fi

pidfile='/noosfero/tmp/pids/server.pid'
if [ -f $pidfile ] ; then
	echo 'Server PID file exists. Removing it...'
	rm $pidfile
fi

#RUN sh script/quick-start --skip-translations
#RUN service postgresql start && sleep 2 && ruby script/sample-data

exec $cmd
