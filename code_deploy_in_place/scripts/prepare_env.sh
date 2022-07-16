#!/bin/bash

mkdir -p /opt/app
adduser app --user-group
chown -R app:app /opt/app
chmod -R g+rwx /opt/app