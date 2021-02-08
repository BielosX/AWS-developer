#!/bin/bash
zip -r my-app.zip -j app
aws s3 cp my-app.zip s3://source-bucket-798791225651-eu-west-1