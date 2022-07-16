#!/bin/bash

yum update
yum install -y ruby
yum install -y wget
wget https://aws-codedeploy-eu-west-1.s3.eu-west-1.amazonaws.com/latest/install
chmod +x ./install
./install auto
