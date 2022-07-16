#!/bin/bash

if systemctl status app.service; then
  systemctl stop app.service
  systemctl disable app.service
  rm -f /opt/app
  userdel -r -f app
fi