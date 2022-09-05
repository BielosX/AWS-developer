#!/bin/bash

function package() {
  rm -rf target
  rm -f latest.zip
  mkdir -p target
  cp src/* target
  pip download -r requirements.txt -d target
  pushd target || exit
  unzip "*.whl"
  find . -name "*.whl" -type f -delete
  zip -r ../latest.zip -- *
  popd || exit
}

case "$1" in
  "package") package ;;
  *) echo "package" ;;
esac