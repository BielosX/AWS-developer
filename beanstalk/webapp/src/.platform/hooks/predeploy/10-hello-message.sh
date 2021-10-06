#!/bin/bash

mkdir -p /etc/webapp
echo '{"helloMessage": "Hello from PreDeploy script"}' >> /etc/webapp/config.json
chmod +r /etc/webapp/config.json