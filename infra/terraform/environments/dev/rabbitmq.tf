resource "kubernetes_namespace" "rabbitmq" {
  metadata {
    name = "rabbitmq"
  }
}

resource "kubernetes_config_map" "rabbitmq_config" {
  metadata {
    name      = "rabbitmq-config"
    namespace = kubernetes_namespace.rabbitmq.metadata[0].name
  }

  data = {
    "rabbitmq.conf" = <<-EOT
      # rabbitmq.conf example settings
      listeners.tcp.default = 5672
      management.listener.port = 15672
      management.listener.ssl = false
    EOT
  }
}

resource "random_password" "erlang_cookie" {
  length = 16
}

resource "kubernetes_stateful_set" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.rabbitmq.metadata[0].name
    labels = {
      app = "rabbitmq"
    }
  }

  spec {
    service_name = "rabbitmq"
    replicas     = 1

    selector {
      match_labels = {
        app = "rabbitmq"
      }
    }

    template {
      metadata {
        labels = {
          app = "rabbitmq"
        }
      }

      spec {
        container {
          name  = "rabbitmq"
          image = "rabbitmq:3.9-management"

          port {
            container_port = 5672
            name           = "amqp"
          }
          port {
            container_port = 15672
            name           = "management"
          }

          volume_mount {
            mount_path = "/etc/rabbitmq"
            name       = "config-volume"
          }

          env {
            name  = "RABBITMQ_ERLANG_COOKIE"
            value = random_password.erlang_cookie.result
          }
          env {
            name  = "RABBITMQ_DEFAULT_USER"
            value = "user"
          }
          env {
            name  = "RABBITMQ_DEFAULT_PASS"
            value = "password"
          }
        }

        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map.rabbitmq_config.metadata[0].name
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "rabbitmq-data"
      }

      spec {
        access_modes = ["ReadWriteOnce"]

        resources {
          requests = {
            storage = "10Gi"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = kubernetes_namespace.rabbitmq.metadata[0].name
    labels = {
      app = "rabbitmq"
    }
  }

  spec {
    cluster_ip = "None" # Headless Service for StatefulSet DNS resolution

    selector = {
      app = "rabbitmq"
    }

    port {
      port        = 5672
      target_port = 5672
      name        = "amqp"
    }

    port {
      port        = 15672
      target_port = 15672
      name        = "management"
    }
  }
}
