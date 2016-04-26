#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
   echo "Please execute Countly installation script with a superuser..." 1>&2
   exit 1
fi

echo "
   ______                  __  __
  / ____/___  __  ______  / /_/ /_  __
 / /   / __ \/ / / / __ \/ __/ / / / /
/ /___/ /_/ / /_/ / / / / /_/ / /_/ /
\____/\____/\__,_/_/ /_/\__/_/\__, /
              http://count.ly/____/
"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#update package index
apt-get update

apt-get -y install python-software-properties wget g++

if !(command -v apt-add-repository >/dev/null) then
    apt-get -y install software-properties-common
fi

#add node.js repo
#echo | apt-add-repository ppa:chris-lea/node.js
# wget -qO- https://deb.nodesource.com/setup_5.x | bash -

#add mongodb repo
#echo "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen" > /etc/apt/sources.list.d/mongodb-10gen-countly.list
#apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.0.list

#update once more after adding new repos
apt-get update

#install nginx
apt-get -y install nginx || (echo "Failed to install nginx." ; exit)

#install node.js
bash $DIR/scripts/install.nodejs.deb.sh || (echo "Failed to install nodejs." ; exit)
# apt-get -y --force-yes install nodejs || (echo "Failed to install nodejs." ; exit)

#install mongodb
apt-get -y --force-yes install mongodb-org || (echo "Failed to install mongodb." ; exit)

#install supervisor
if [ "$INSIDE_DOCKER" != "1" ]
then
	apt-get -y install supervisor || (echo "Failed to install supervisor." ; exit)
fi

#install imagemagick
apt-get -y install imagemagick

#install sendmail
apt-get -y install sendmail

#install babel
npm install -g babel-cli

#install less
npm install -g less

#install grunt & npm modules
( cd $DIR/.. ; npm install -g grunt-cli --unsafe-perm; npm install;  )

#configure and start nginx
cp /etc/nginx/sites-enabled/default $DIR/config/nginx.default.backup
cp $DIR/config/nginx.server.conf /etc/nginx/sites-enabled/default
cp $DIR/config/nginx.conf /etc/nginx/nginx.conf
if [ "$INSIDE_DOCKER" != "1" ]
then
	/etc/init.d/nginx restart
fi

cp -n $DIR/../frontend/express/public/javascripts/countly/countly.config.sample.js $DIR/../frontend/express/public/javascripts/countly/countly.config.js

bash $DIR/scripts/detect.init.sh

#create api configuration file from sample
cp -n $DIR/../api/config.sample.js $DIR/../api/config.js

#create app configuration file from sample
cp -n $DIR/../frontend/express/config.sample.js $DIR/../frontend/express/config.js

if [ ! -f $DIR/../plugins/plugins.json ]; then
	cp $DIR/../plugins/plugins.default.json $DIR/../plugins/plugins.json
fi

#install plugins
bash $DIR/scripts/countly.install.plugins.sh

#get web sdk
countly update sdk-web

#compile scripts for production
cd $DIR/../frontend/express/public/javascripts
babel --presets es2015,react react_components/ --out-dir react_components_compiled/
babel --presets es2015,react react_pages/ --out-dir react_pages_compiled/
cd $DIR/../frontend/express/public/stylesheets

lessc sidebar.less compiled_css_sidebar.css
lessc calendar.less compiled_css_calendar.css
lessc tables.less compiled_css_tables.css
lessc map.less compiled_css_map.css
lessc selector_with_search.less compiled_css_selector_with_search.css
lessc applications.less compiled_css_applications.css
lessc multi_select.less compiled_css_multi_select.css
lessc select.less compiled_css_select.css
lessc manage_users.less compiled_css_manage_users.css
lessc topbar.less compiled_css_topbar.css
lessc configurations.less compiled_css_configurations.css
lessc crash_details.less compiled_css_crash_details.css
lessc line_chart.less compiled_css_line_chart.css
lessc platforms.less compiled_css_platforms.css

cd $DIR/../ && grunt dist-all

# prepare maps data
apt-get install -y zip

cd $DIR/scripts
# download geo data for datamaps visualization from "themapping.org"
if wget -q http://thematicmapping.org/downloads/TM_WORLD_BORDERS-0.3.zip;
  then echo "done";
  else wget http://static.count.ly/TM_WORLD_BORDERS-0.3.zip;
fi
unzip ./TM_WORLD_BORDERS-0.3.zip -d ./geo_data
# create mongodb table with geo data
cd $DIR/scripts
node ./create_country_table.js

if wget -q http://download.geonames.org/export/dump/cities1000.zip;
  then echo "done";
  else wget http://static.count.ly/cities1000.zip;
fi

unzip cities1000.zip
node create_city_table.js

#finally start countly api and dashboard
if [ "$INSIDE_DOCKER" != "1" ]
then
	countly start
fi
