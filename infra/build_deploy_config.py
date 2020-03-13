#!/usr/bin/env python3
import os
import argparse
import textwrap

infra_root = os.path.abspath(os.path.dirname(__file__))

env_vars_to_infra = [
    "GOOGLE_PROJECT_ID",
    "GOOGLE_REGION",
    "GOOGLE_APPLICATION_CREDENTIALS",
    "GITLAB_SERVER_NAME"
]

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("component")
args = parser.parse_args()

autogen_message = textwrap.dedent(
    f"""
    # Auto-generated during infra build process.
    # Please edit infra/build_deploy_config.py directly.
    
    """
)[1:]

terraform_providers = autogen_message + textwrap.dedent(
    f"""
    provider "google" {{
      credentials = file("{os.environ["GOOGLE_APPLICATION_CREDENTIALS"]}")
      project     = "{os.environ["GOOGLE_PROJECT_ID"]}"
      region      = "{os.environ["GOOGLE_REGION"]}"
    }}
    """
)

terraform_variables = autogen_message
for key in env_vars_to_infra:
    terraform_variables += textwrap.dedent(
        f"""
        variable "{key}" {{
          default = "{os.environ[key]}"
        }}
        """
    )

terraform_backend = autogen_message + textwrap.dedent(
    f"""
    terraform {{
      backend "gcs" {{
        bucket = "{os.environ["TERRAFORM_BACKEND_STATE_BUCKET"]}"
        prefix = "{os.environ["GITLAB_SERVER_NAME"]}/{args.component}"
      }}
    }}
    """
)

with open(os.path.join(infra_root, args.component, "variables.tf"), "w+") as f:
    f.write(terraform_variables)

with open(os.path.join(infra_root, args.component, "backend.tf"), "w+") as f:
    f.write(terraform_backend)

with open(os.path.join(infra_root, args.component, "providers.tf"), "w+") as f:
    f.write(terraform_providers)
