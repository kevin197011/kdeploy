#!/usr/bin/env bash


export DEBIAN_FRONTEND=noninteractive

echo "app: $1 => version: $2"
apt-get update
apt-get install -y ruby-full
gem install kdeploy
