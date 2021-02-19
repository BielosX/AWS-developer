#!/bin/bash
cd app || exit
zip -r ../my-app.zip ./*
cd ..
aws s3 cp my-app.zip s3://source-bucket-798791225651-eu-west-1
rm my-app.zip