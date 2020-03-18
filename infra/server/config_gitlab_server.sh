#!/bin/bash

set -euo pipefail

hostname=$1
github_client_id=$2
github_client_secret=$3

github_login_config="gitlab_rails['omniauth_providers'] = [
    {
      \"name\" => \"github\",
      \"app_id\" => \"${github_client_id}\",
      \"app_secret\" => \"${github_client_secret}\",
	  \"url\" => \"https://github.com/\",
      \"args\" => { \"scope\" => \"user:email\" }
    }
  ]"

config_file="/etc/gitlab/gitlab.rb"
local_config_marker="### BEGIN GITLAB CONFIG"
# This command removes the line containing ${local_config_marker}, and all following lines
sudo sed -i -e "/${local_config_marker}/,\$d" ${config_file}
sudo sed -i "s/^external_url.*/external_url 'https:\/\/${hostname}'/" ${config_file}
echo "${local_config_marker}" | sudo tee -a ${config_file}
echo "gitlab_rails['omniauth_enabled'] = true" | sudo tee -a ${config_file}
echo $github_login_config | sudo tee -a ${config_file}
echo "gitlab_rails['omniauth_block_auto_created_users'] = true" | sudo tee -a ${config_file}
echo "gitlab_rails['omniauth_allow_single_sign_on'] = true" | sudo tee -a ${config_file}
echo "nginx['enable'] = true" | sudo tee -a ${config_file}
echo "nginx['listen_https'] = false" | sudo tee -a ${config_file}
echo "nginx['listen_port'] = 80" | sudo tee -a ${config_file}
echo "nginx['proxy_set_headers'] = { 'X-Forwarded-Proto' => 'https' }" | sudo tee -a ${config_file}
echo "gitlab_rails['pipeline_schedule_worker_cron'] = \"* * * * *\"" | sudo tee -a ${config_file}

# This command removes the line containing ${local_config_marker}, and all following lines
sudo sed -i -e "/${local_config_marker}/,\$d" /etc/hosts
echo "${local_config_marker}" | sudo tee -a /etc/hosts
echo "127.0.0.1 ${hostname}" | sudo tee -a /etc/hosts
sudo hostname ${hostname}

sudo gitlab-ctl reconfigure ; sudo gitlab-ctl restart
