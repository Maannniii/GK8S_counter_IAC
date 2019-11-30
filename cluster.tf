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

resource "google_container_cluster" "primary" {
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
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${self.name} --region ${self.location} --project ${var.project}"
    interpreter = [
      "bash",
      "-c"]
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

resource "local_file" "kubeconfig" {
  filename = "~/.kube/config"
  directory_permission = "0755"
  file_permission = "0644"
  depends_on = [
    google_container_cluster.primary]
}

provider "kubernetes" {
  load_config_file = true
  config_path = local_file.kubeconfig.filename
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = "counter"
  }
}

resource "kubernetes_config_map" "redis_url" {
  metadata {
    name = "redis-config"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }
  data = {
    REDIS_URL = join("", [
      "redis://",
      google_redis_instance.cache.host,
      ":",
      google_redis_instance.cache.port,
      "/0"])
  }
}

resource "kubernetes_deployment" "counter" {
  metadata {
    name = "counter"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  spec {
    replicas = 3
    strategy {
      rolling_update {
        max_surge = "1"
        max_unavailable = "1"
      }
    }
    selector {
      match_labels = {
        app = "UI"
      }
    }

    template {
      metadata {
        labels = {
          app = "UI"
        }
      }

      spec {
        container {
          image = "tarunbhardwaj/flask-counter-app"
          name = "flask-counter-app"
          port {
            container_port = "5000"
          }
          env_from {
            config_map_ref {
              name = kubernetes_config_map.redis_url.metadata[0].name
            }
          }
          resources {
            limits {
              cpu = "0.5"
              memory = "512Mi"
            }
            requests {
              cpu = "250m"
              memory = "50Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 5000
            }

            initial_delay_seconds = 10
            period_seconds = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "frontendservice" {
  metadata {
    name = "frontend"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }
  spec {
    type = "LoadBalancer"
    port {
      port = 80
      target_port = kubernetes_deployment.counter.spec[0].template[0].spec[0].container[0].port[0].container_port
    }
    selector = {
      app = "UI"
    }
  }
}

resource "kubernetes_ingress" "ingress" {
  metadata {
    name = "network"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  spec {
    backend {
      service_name = kubernetes_service.frontendservice.metadata[0].name
      service_port = kubernetes_service.frontendservice.spec[0].port[0].port
    }

    rule {
      http {
        path {
          backend {
            service_name = kubernetes_service.frontendservice.metadata[0].name
            service_port = kubernetes_service.frontendservice.spec[0].port[0].port
          }

          path = "/*"
        }
      }
    }
  }
}