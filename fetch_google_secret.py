#!/usr/bin/env python3
"""
This script fetches the latest version of a secret value from Google's Secrets Manager, given a secret name.

Note: this strips newlines and spaces from the secret value returned.

Usage: fetch_google_secret secret-name
Example: fetch_google_secret gcp-credentials.json
"""
import os
import argparse

from google.cloud.secretmanager import SecretManagerServiceClient


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("secret", help="The id of a secret in Google's secrets manager.")
args = parser.parse_args()


def get_secret(secret):
    client = SecretManagerServiceClient()
    try:
        project = os.environ["GOOGLE_PROJECT_ID"]
    except KeyError:
        raise RuntimeError('GOOGLE_PROJECT_ID is unset.  Please run "source environment" to set GOOGLE_PROJECT_ID.')
    response = client.access_secret_version(f'projects/{project}/secrets/{secret}/versions/latest')
    return response.payload.data.decode('UTF-8')


print(get_secret(args.secret).strip())
