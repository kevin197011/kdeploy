#!/usr/bin/env bash

echo "app: $1 => version: $2"
apt update
apt install ruby-full
gem install kdeploy
