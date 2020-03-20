// GKE Cluster
resource "google_container_cluster" "gitlab-cluster" {
  name               = "gitlab-cluster"
  location           = var.GOOGLE_REGION

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true

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
    name      = "tiller"
    namespace = "kube-system"
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
    name      = "tiller"
    namespace = "kube-system"
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
  region = var.GOOGLE_REGION
}

locals {
  gitlab_address = google_compute_address.static_cluster_ip.address
}

resource "helm_release" "gitlab" {
  name       = "gitlab-runner"
  repository = data.helm_repository.gitlab_helm_repository.name
  chart      = "gitlab"
  version    = "2.3.7"
  timeout    = 600

  values = [file("helm_values.yml")]

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
  name = "ipv4-address"
}

// Enable API
resource "google_project_service" "gke" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}
