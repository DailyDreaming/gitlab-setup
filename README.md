## Gitlab Setup in GCE/GKE

This project stands up a self-hosted gitlab server and kubernetes cluster (which serves CI/CD test runners) using google's cloud platform in terraform.

This server is intended to run CI/CD for any github repository.  It consists of a google cloud-hosted server and kubernetes cluster.  The server itself is a small `n1-standard-2` instance, installed with gitlab-ee.  A gke kubernetes cluster is then spun up separately and registered to the server as the runner pool.  If a github repository is registered and mirrored, then any commit made to the parent github repository will send an event to the mirrored gitlab repository and trigger the kubernetes cluster to spin up a pod to run tests according to that repository's `.gitlab-ci.yml` config (see: https://docs.gitlab.com/ee/ci/yaml/).

Note:
 - This installs gitlab-ee (not the community edition), which requires a license key at some point (it will work after installation but some features will be disabled).  The main feature gitlab-ee provides that the community edition does not is github repo mirroring.  Open source projects can apply for a free license.

Prior to installation, you will need to create a few resources:

# Set Up a Domain
First, my organization forbids access to google's domain service for some reason, so I had to register my domain elsewhere.  There should be no reason why this couldn't be handled in terraform for a google domain, I just could not do so for institutional reasons.  So setting this up takes a little more effort:

1. Register a domain somewhere.  I chose AWS's Route 53 because it was easy and available, but any provider should be fine.  AWS said it might take up to 3 days to register, but in reality it took about 3 minutes.
1. Once the server is spun up, it will have a static IP and you will have to come back to this domain and add a "Record Set".  Use a simple record set type A (the other record sets NS and SOA should already exist and have been created for you; don't touch these), adding the IPv4 address, and a TTL (I choose the default, which was 300 seconds).  Once this is done, this won't work immediately, but after a short wait, your hosted gitlab server login should appear at this domain.

# Set Up an SSH Key Pair as a Google Secret
To remotely access the server, we generate and register our own key SSH pair, and store it in google's secret manager.

On Ubuntu this can be done with: `ssh-keygen -t rsa -b 4096`

There should be a private key and a public key.  Google only allows you to make secrets in the json format, so you'll need to make a json file with them with `public` as the key to the actual public key value, and `private` with the key to the actual private key value, like this:

```
{
    "public": "------",
    "private": "------\n------\n------\n" 
}
```

The public key is one line, but newlines will have to be literal in the private key as shown (TODO: Include script to do this.).

Once this json file is created, it can be uploaded as a google secret with the following:

```
gcloud secrets create gitlab_server-ssh_keys --data-file="ssh_keys.json" --replication-policy=automatic
```

Note, make sure the same as `SECRETSTORE_SSH_KEYS`.

# Set Up an Github App Client Key Pair as a Google Secret

# TODO: Write Steps to create a Github App Client Key Pair

```
gcloud secrets create gitlab_server-github_app --data-file="github_keys.json" --replication-policy=automatic
```

# Google API Access:
1. You'll need to access google's "API access" API or terraform can't access information about your access to APIs: https://console.developers.google.com/apis/api/serviceusage.googleapis.com/overview

# Set Up the Python Environment and Dependencies:
This is a python project so set up a virtualenv and install dependencies:

    virtualenv -p python3.7 v3nv
    . v3nv/bin/activate
    pip install -r requirements.txt

Run `source environment` before running any make commands.

Run `make all` from the root to populate all provider information and variable files for terraform.

# Create the Server and the Kubernetes Cluster:

Run `make apply` to create the server and cluster.

# TODO: Additional Steps to register the runner.
