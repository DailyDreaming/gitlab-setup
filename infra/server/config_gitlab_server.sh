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

# ${local_config_marker} must be a unique line
# everything after it is code we (this script) appended to the end of the file
local_config_marker="### BEGIN GITLAB CONFIG"

# here we reset any previous changes this script made to the file by wiping
# the ${local_config_marker} line and all lines after it (if they exist)
sudo sed -i -e "/${local_config_marker}/,\$d" ${config_file}
sudo sed -i "s/^external_url.*/external_url 'https:\/\/${hostname}'/" ${config_file}

# Start with a new ${local_config_marker} so that we can identify our changes later and reset them
echo "${local_config_marker}" | sudo tee -a ${config_file}

# Configure gitlab to allow github users to able to login; they start blocked and must be manually added by an admin
echo "gitlab_rails['omniauth_enabled'] = true" | sudo tee -a ${config_file}
echo $github_login_config | sudo tee -a ${config_file}
echo "gitlab_rails['omniauth_block_auto_created_users'] = true" | sudo tee -a ${config_file}
echo "gitlab_rails['omniauth_allow_single_sign_on'] = true" | sudo tee -a ${config_file}
echo "gitlab_rails['pipeline_schedule_worker_cron'] = \"* * * * *\"" | sudo tee -a ${config_file}

# Allow LetsEncrypt to create, maintain, and renew our SSL Certificate keys
echo "letsencrypt['enable'] = true" | sudo tee -a ${config_file}
echo "letsencrypt['auto_renew'] = true" | sudo tee -a ${config_file}
echo "letsencrypt['auto_renew_hour'] = 0" | sudo tee -a ${config_file}
echo "letsencrypt['auto_renew_minute'] = 30" | sudo tee -a ${config_file}
echo "letsencrypt['auto_renew_day_of_month'] = \"*/4\"" | sudo tee -a ${config_file}

# Set Up NGINX to forward http to https using the SSL certificate above
echo "nginx['enable'] = true" | sudo tee -a ${config_file}
echo "nginx['redirect_http_to_https'] = true" | sudo tee -a ${config_file}
# echo "echo \"nginx['custom_gitlab_server_config'] = \"location /.well-known/acme-challenge/ {\n root /var/opt/gitlab/nginx/www/; \n}\n\"" | sudo tee -a ${config_file}


# We modify /etc/hosts; We again use ${local_config_marker} to separate our changes and we begin by resetting
sudo sed -i -e "/${local_config_marker}/,\$d" /etc/hosts
echo "${local_config_marker}" | sudo tee -a /etc/hosts
echo "127.0.0.1 ${hostname}" | sudo tee -a /etc/hosts
sudo hostname ${hostname}

# sudo gitlab-ctl reconfigure ; sudo gitlab-ctl restart
