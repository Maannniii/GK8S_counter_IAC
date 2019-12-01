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

resource "google_container_cluster" "primary" {
  name = "counter"
  location = var.region
  remove_default_node_pool = true
  initial_node_count = 1

  master_auth {
    username = var.k8s_username
    password = var.k8s_password
    # don't display certificates on terraform apply
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # enable pod auto scaling and load balancing by default enabled
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

  # create kube config file when the cluster is created
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${self.name} --region ${self.location} --project ${var.project}"
    interpreter = [
      "bash",
      "-c"]
  }
  # network to be attached to
  network = google_compute_network.counter-network.self_link
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name = "nodepool"
  # This is a regional cluster in order to make sure fault tolerance
  location = var.region
  cluster = google_container_cluster.primary.name
  # no of nodes be created in each zone
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

  //  autoscaling {
  //    max_node_count = 9
  //    min_node_count = 3
  //  }
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