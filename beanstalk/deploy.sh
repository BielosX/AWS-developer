#!/bin/bash

terraform init
terraform apply
find . -name "*.zip" -exec rm -rf {} \;
