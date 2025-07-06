#!/usr/bin/env bash

echo "app: $1 => version: $2"
apt-get update
apt-get install -y ruby-full
gem install kdeploy
