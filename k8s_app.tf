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

output "loadbalancer" {
  value = join("", [
    "http://",
    kubernetes_service.frontendservice.load_balancer_ingress[0].ip])
}