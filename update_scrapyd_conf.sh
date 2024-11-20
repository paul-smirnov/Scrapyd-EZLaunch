#!/bin/bash

# Set default username and password if not provided
: ${SCRAPYD_USERNAME:=admin}
: ${SCRAPYD_PASSWORD:=admin}

# Update the scrapyd.conf file
sed -i "s/^username.*/username = $SCRAPYD_USERNAME/" /etc/scrapyd/scrapyd.conf
sed -i "s/^password.*/password = $SCRAPYD_PASSWORD/" /etc/scrapyd/scrapyd.conf
