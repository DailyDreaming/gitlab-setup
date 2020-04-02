SHELL=/bin/bash

ifndef GITLAB_HOME
$(error Please run "source environment" in the gitlab-setup repo root directory before running make commands)
endif

ifeq ($(shell which kubectl),)
$(error Please install kubectl using "https://kubernetes.io/docs/tasks/tools/install-kubectl/")
endif

ifeq ($(shell which jq),)
$(error Please install jq using "apt-get install jq" or "brew install jq")
endif

ifeq ($(findstring Terraform v0.12.23, $(shell terraform --version 2>&1)),)
$(error You must use Terraform v0.12.23, please check your terraform version.)
endif

ifeq ($(findstring Python 3.7, $(shell python --version 2>&1)),)
$(error Please run make commands from a Python 3.7 virtualenv)
endif
