// GKE Cluster
resource "google_container_cluster" "gitlab-cluster" {
  name               = "gitlab-cluster"
  project = var.GOOGLE_PROJECT_ID
  location           = var.GOOGLE_REGION

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  # remove_default_node_pool = true

  initial_node_count = 1

  network    = "default"
  // subnetwork = google_compute_subnetwork.subnetwork.self_link TODO

  ip_allocation_policy {
    # Allocate ranges automatically
    cluster_ipv4_cidr_block  = ""
    services_ipv4_cidr_block = ""
  }

  enable_legacy_abac = true

  # Setting an empty username and password explicitly disables basic auth
  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = true
    }
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.full_control",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  timeouts {
    create = "2h"
    delete = "2h"
    update = "2h"
  }

  depends_on = [google_project_service.gke]
}

resource "google_container_node_pool" "gitlab" {
  name       = "gitlab"
  location   = var.GOOGLE_REGION
  cluster    = google_container_cluster.gitlab-cluster.name
  node_count = 1
  depends_on = []

  node_config {
    preemptible  = false
    machine_type = "n1-standard-4"

    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.full_control",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

resource "kubernetes_service_account" "tiller" {
  metadata {
    name      = local.kube_service_account
    namespace = local.kube_namespace
  }
}

resource "kubernetes_cluster_role_binding" "tiller-admin" {
  metadata {
    name = "tiller-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = local.kube_service_account
    namespace = local.kube_namespace
  }
}

resource "kubernetes_storage_class" "pd-ssd" {
  metadata {
    name = "pd-ssd"
  }

  storage_provisioner = "kubernetes.io/gce-pd"

  parameters = {
    type = "pd-ssd"
  }
}

data "helm_repository" "gitlab_helm_repository" {
  name = "gitlab"
  url  = "https://charts.gitlab.io"
}

data "google_compute_address" "gitlab_compute_address" {
  name   = "gitlab-compute-address"
  project = var.GOOGLE_PROJECT_ID
  region = var.GOOGLE_REGION
}

locals {
  gitlab_address = google_compute_address.static_cluster_ip.address
}

// Documentation for this Helm Chart: https://docs.gitlab.com/runner/install/kubernetes.html
resource "helm_release" "gitlab" {
  name = "gitlab-runner"
  chart = "gitlab-runner"
  repository = data.helm_repository.gitlab_helm_repository.name
  namespace = local.kube_namespace
  timeout    = 600

  values = [file("helm_values.yml")]

  set {
    name = "runnerRegistrationToken"
    value = local.gitlab_runner_token
  }

  set {
    name = "gitlabUrl"
    value = "https://${var.EXTERNAL_URL}/"
  }

  set {
    name = "rbac.serviceAccountName"
    value = local.kube_service_account
  }

  set {
    name = "runners.serviceAccountName"
    value = local.kube_service_account
  }

  set {
    name = "runners.namespace"
    value = local.kube_namespace
  }

  depends_on = [
    kubernetes_cluster_role_binding.tiller-admin,
    kubernetes_storage_class.pd-ssd,
    null_resource.sleep_for_cluster_fix_helm_6361,
  ]
}


resource "null_resource" "sleep_for_cluster_fix_helm_6361" {
  provisioner "local-exec" {
    command = "sleep 180"
  }
  depends_on = [google_container_cluster.gitlab-cluster]
}

resource "google_compute_address" "static_cluster_ip" {
  project = var.GOOGLE_PROJECT_ID
  name = "ipv4-address"
}

// Enable APIs
resource "google_project_service" "gke" {
  service            = "container.googleapis.com"
  project = var.GOOGLE_PROJECT_ID
  disable_on_destroy = false
}

// Pull Secrets
data "external" "gitlab_runner_token" {
  // unfortunately google secrets cannot be used as a data source like aws secrets can so this is a work-around
  program = ["python3", "../../fetch_google_secret.py", "${var.SECRETSTORE_RUNNER_TOKEN}"]
}

locals {
  gitlab_runner_token =  data.external.gitlab_runner_token.result.token
  kube_namespace = "kube-system"
  kube_service_account = "tiller"
}
