#! /usr/bin/env python
import gitlab
import time
import requests
import json
import os

gitlab_server = os.environ['EXTERNAL_URL']
private_token = ''
github_username = ''
github_email = ''

gl = gitlab.Gitlab(f'http://{gitlab_server}', private_token=private_token)


def get_github_user_id(github_username):
    session = requests.Session()
    res = session.get(f'https://api.github.com/users/{github_username}')
    if res.ok:
        github_user_id = json.loads(res.text)['id']
        return github_user_id
    elif res.status_code == 404:
        raise RuntimeError(f'Github User: {github_username} does not exist!')
    else:
        res.raise_for_status()


user_data = {'email': github_email,
             'username': github_username,  # this must be their github username
             'name': github_username,  # this becomes their gitlab username
             'reset_password': True,  # an actual password or this is required
             "provider": "github",
             "extern_uid": get_github_user_id(github_username)}
gl.users.create(user_data)
time.sleep(10)
for user in gl.users.list():
    if user.email == github_email:
        user.unblock()
        user.save()
