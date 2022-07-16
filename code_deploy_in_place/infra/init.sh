#!/bin/bash

yum update
yum install -y ruby
yum install -y wget
wget https://aws-codedeploy-eu-west-1.s3.eu-west-1.amazonaws.com/latest/install
chmod +x ./install
./install auto

wget -O corretto-11.rpm https://corretto.aws/downloads/latest/amazon-corretto-11-x64-al2-jdk.rpm
yum localinstall -y corretto-11.rpm
