resource "google_compute_instance" "smallspark" {
  name = var.GITLAB_SERVER_NAME
  project = var.GOOGLE_PROJECT_ID
  zone = var.GOOGLE_ZONE
  machine_type = "n1-standard-2"
  boot_disk {
    initialize_params {
      image = "ubuntu-1804-bionic-v20200218"  // https://console.cloud.google.com/compute/images
      type = "pd-ssd"
    }
  }
  network_interface {
    network = "default"
    access_config {
      network_tier = "PREMIUM"
      nat_ip = google_compute_address.static_server_ip.address
    }
  }

  tags = ["apply-gitlab-firewall"]

  timeouts {
    create = "2h"
    delete = "2h"
    update = "2h"
  }

  // hostname = ""

  // Adding METADATA Key Value pairs to VM-Series GCE instance
  metadata = {
    sshKeys = "${var.GITLAB_USERNAME}:${local.public_ssh_key}"
  }

  // these timeout and so need to A. spin-wait for the instance B. put a dependency on this and C. extend timeout
  // https://github.com/terraform-providers/terraform-provider-oci/issues/868
  // provisioner "file" {
  //   source      = "install_gitlab.sh"
  //   destination = "/tmp/install_gitlab.sh"
  // }
  //
  // provisioner "file" {
  //   source      = "config_gitlab_server.sh"
  //   destination = "/tmp/config_gitlab_server.sh"
  // }
  //
  // provisioner "remote-exec" {
  //       inline = [
  //           "chmod +x /tmp/install_gitlab.sh",
  //           "chmod +x /tmp/config_gitlab_server.sh",
  //           "/tmp/install_gitlab.sh",
  //           "/tmp/config_gitlab_server.sh ${var.EXTERNAL_URL} ${local.github_client_id} ${local.github_client_secret}"
  //       ]
  // }

  allow_stopping_for_update = true
  can_ip_forward = true
  // deletion_protection = true
}

resource "google_compute_firewall" "gitlab-firewall" {
  name    = "gitlab-firewall"
  project = var.GOOGLE_PROJECT_ID
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  allow {
    protocol = "udp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["apply-gitlab-firewall"]  // apply firewall to any instance with this tag
}

resource "google_compute_address" "static_server_ip" {
  name = "ipv4-address"
  project = var.GOOGLE_PROJECT_ID
}

// Enable APIs
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  project = var.GOOGLE_PROJECT_ID
  disable_on_destroy = false
}

resource "google_project_service" "service_networking" {
  service            = "servicenetworking.googleapis.com"
  project = var.GOOGLE_PROJECT_ID
  disable_on_destroy = false
}

resource "google_project_service" "cloudresourcemanager" {
  service            = "cloudresourcemanager.googleapis.com"
  project = var.GOOGLE_PROJECT_ID
  disable_on_destroy = false
}

// Pull Secrets
data "external" "github_app" {
  // unfortunately google secrets cannot be used as a data source like aws secrets can so this is a work-around
  program = ["python3", "../../fetch_google_secret.py", "${var.SECRETSTORE_GITHUB_APP}"]
}

data "external" "ssh_keys" {
  // unfortunately google secrets cannot be used as a data source like aws secrets can so this is a work-around
  program = ["python3", "../../fetch_google_secret.py", "${var.SECRETSTORE_SSH_KEYS}"]
}

locals {
  github_client_id =  data.external.github_app.result.client_id
  github_client_secret =  data.external.github_app.result.client_secret
  public_ssh_key =  data.external.ssh_keys.result.public
  private_ssh_key =  data.external.ssh_keys.result.private
}
