#!/bin/bash

# Adapted from: https://about.gitlab.com/install/#ubuntu

set -euo pipefail

sudo apt-get update && sudo apt-get -y upgrade
sudo apt-get install -y curl openssh-server ca-certificates
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh | sudo bash
sudo apt-get install gitlab-ee
