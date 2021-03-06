# use the next debian release (because nodejs is not available in wheezy)
FROM debian:jessie
MAINTAINER Anthony.Baire@irisa.fr


###############################################################################
# system configuration (packages, user account) + unpack etherpad-lite
###############################################################################

# get the latest package lists and apply the needed upgrades
RUN apt-get update && apt-get -y dist-upgrade


# install all required packages
RUN apt-get -y install --no-install-recommends nodejs unzip curl python libssl-dev pkg-config build-essential npm

# make nodejs available as the command 'node'
RUN ln -s /usr/bin/nodejs /usr/local/bin/node


# create a dedicated user
RUN useradd --create-home etherpad

# install npm packages
#
# We install the npm pachages before importing the whole source tree (COPY .
# ...). Thus the dependencies will be reinstalled only when the package.json
# file is updated.
COPY src/package.json /tmp/ep/
RUN chown -R etherpad: /tmp/ep && su etherpad -c 'cd /tmp/ep && npm install .'

# install the sources into /opt/etherpad
COPY . /opt/etherpad

# make it owned by the etherpad user
RUN chown -R etherpad: /opt/etherpad

# set the default user to 'etherpad'
# (will affect all containers running this image, including subsequent RUN
# commands)
USER etherpad

# set the default working directory
# (will affect all containers running this image, including subsequent RUN
# commands)
WORKDIR /opt/etherpad


###############################################################################
# tune etherpad and install its js dependencies
###############################################################################


# store the session key in the external volume /opt/etherpad/var (to make it
# persistent)
RUN ln -s var/SESSIONKEY.txt


###############################################################################
# runtime config
###############################################################################

# set the default command for the container
CMD ["bin/run.sh"]

# indicate that the containers running this image shall be terminated with
# SIGINT (instead of the default SIGTERM) when 'docker stop' is called
# (it appears the etherpad does not handles SIGTERM)
STOPSIGNAL SIGINT

# provide a command to be run periodically by the docker engine to check if the
# container is correctly running. The status is displayed in "docker ps" and
# full details are provided in "docker inspect"
#
# This command ensures verifies that etherpad is responding to HTTP requests
# within one second.
HEALTHCHECK CMD curl --fail --max-time 1 -o /dev/null http://localhost:9001/

# Expose tcp port 9001 and mark /opt/etherpad/var as an external volume
#
# NOTE:	these lines are not strictly required, since 'docker run' allows
#	publishing arbitrary ports and binding arbitrary mount points.
#
#	Including them in the Dockerfile (thus in the image metadata) has the
#	following effects:
#	  EXPOSE port
#	  - all exposed ports are automatically published when 'docker run' is
#	    called with option -P (publish all)
#	  - when using legacy links: connections to these ports from the linked
#	    containers will be automatically whitelisted in the firewall (if
#	    daemon is run with --icc=false)
#	  VOLUME path
#	  - if 'docker run' is called without binding this path, then an
#	  anonymous volume is created on-the-fly for storing this path
#	  (see 'docker volume --help')
EXPOSE 9001
VOLUME /opt/etherpad/var
