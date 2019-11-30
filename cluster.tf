variable "project" {
  description = "Google Cloud project ID"
  default = "projectid"
}
variable "region" {
  description = "Google Cluster Region"
  default = "asia-southeast1"
}
variable "credentials" {
  description = "Google Cloud Service Account"
  default = "account.json"
}
variable "k8s_username" {
  description = "Kubernetes username"
  type = string
  default = ""
}
variable "k8s_password" {
  description = "Kubernetes password"
  type = string
  default = ""
}

provider "google" {
  project = var.project
  region = var.region
  credentials = file(var.credentials)
}

data "google_compute_zones" "all" {}

resource "google_compute_network" "counter-network" {
  name = "counter-net"
  lifecycle {
    ignore_changes = []
    create_before_destroy = false
    prevent_destroy = false
  }
}

rresource "google_container_cluster" "primary" {
  name = "counter"
  location = var.region
  remove_default_node_pool = true
  initial_node_count = 1

  master_auth {
    username = var.k8s_username
    password = var.k8s_password
    client_certificate_config {
      issue_client_certificate = false
    }
  }
  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
  }
  ip_allocation_policy {

  }
  network = google_compute_network.counter-network.self_link
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name = "nodepool"
  location = var.region
  cluster = google_container_cluster.primary.name
  node_count = 1
  management {
    auto_repair = true
    auto_upgrade = true
  }
  node_config {
    preemptible = true
    machine_type = "custom-1-1024"
    disk_size_gb = 10
    metadata = {
      disable-legacy-endpoints = "true"
    }
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

resource "google_redis_instance" "cache" {
  name = "redis"
  display_name = "Redis HA"
  tier = "STANDARD_HA"
  memory_size_gb = 1

  location_id = data.google_compute_zones.all.names[0]
  alternative_location_id = data.google_compute_zones.all.names[1]
  authorized_network = google_compute_network.counter-network.self_link
}