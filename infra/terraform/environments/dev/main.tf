resource "kind_cluster" "this" {
  name            = var.cluster_name
  node_image      = "kindest/node:${var.cluster_version}"
  kubeconfig_path = pathexpand(var.kubeconfig_file)
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    containerd_config_patches = [
      <<-EOT
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
        endpoint = ["http://local-registry:5000"]
      EOT
    ]

    node {
      role = "control-plane"
      extra_port_mappings {
        container_port = 80
        host_port      = var.host_port

      }
      extra_port_mappings {
        container_port = 30080
        host_port      = var.host_port_30080
      }

    }

    node {
      role = "worker"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = pathexpand(var.kubeconfig_file)
  }
}

provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig_file)
}


resource "null_resource" "execute_python" {
  depends_on = [kind_cluster.this]
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command     = "python3 build_and_load_images.py"
    working_dir = "${path.module}/../../../scripts/"
  }
}


# resource "kubernetes_config_map" "local_registry_hosting" {
#   metadata {
#     name      = "local-registry-hosting"
#     namespace = "kube-public"
#   }

#   data = {
#     "localRegistryHosting.v1" = <<-EOT
#       host: "localhost:${var.reg_port}"
#       help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
#     EOT
#   }
# }

resource "kubernetes_secret" "minio_secret_in_app_ns" {
  metadata {
    name      = "minio-secret"
    namespace = "default" # Replace with your app's namespace
  }

  data = {
    accesskey = "admin"
    secretkey = random_password.minio.result
  }

  type = "Opaque"
}



resource "kubernetes_deployment" "test-deploy" {
  metadata {
    name = "terraform"
    labels = {
      test = "MyApp"
    }
  }

  depends_on = [kubernetes_secret.minio_secret_in_app_ns]

  spec {
    replicas = 1

    selector {
      match_labels = {
        test = "MyApp"
      }
    }

    template {
      metadata {
        labels = {
          test = "MyApp"
        }
      }

      spec {
        container {
          image = "texura_api:latest"
          name  = "api"

          image_pull_policy = "IfNotPresent"

          port {
            container_port = 7070
          }

          env {
            name  = "STABLE_DIFFUSION_SERVICE_URL"
            value = "http://texture-engine:8080/invocations"
          }

          env {
            name  = "MINIO_ENDPOINT"
            value = "http://minio.block-storage.svc.cluster.local"
          }

          env {
            name = "AWS_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                name = "minio-secret"
                key  = "accesskey"
              }
            }
          }

          env {
            name = "AWS_SECRET_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = "minio-secret"
                key  = "secretkey"
              }
            }
          }

          env {
            name  = "MINIO_REGION"
            value = "us-east-1"
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 7070

              http_header {
                name  = "X-Custom-Header"
                value = "Awesome"
              }
            }

            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "texura_api_nodeport" {
  metadata {
    name      = "texura-api"
    namespace = "default"
  }

  spec {
    selector = {
      test = "MyApp" # this label must match your pod/deployment labels
    }

    type = "NodePort"

    port {
      port        = 7070  # service port inside the cluster
      target_port = 7070  # container port your pod listens on
      node_port   = 30080 # port exposed on the node (your local machine)
      protocol    = "TCP"
    }
  }
}


resource "kubernetes_deployment" "test-deploy2" {
  metadata {
    name = "texture-engine-deployment"
    labels = {
      test = "TextureEngine"
    }
  }

  depends_on = [kubernetes_secret.minio_secret_in_app_ns]

  spec {
    replicas = 1

    selector {
      match_labels = {
        test = "TextureEngine"
      }
    }

    template {
      metadata {
        labels = {
          test = "TextureEngine"
        }
      }

      spec {
        container {
          image = "texture_engine:latest"
          name  = "texture-engine"

          image_pull_policy = "IfNotPresent"

          port {
            container_port = 8080
          }

          env {
            name  = "MINIO_ENDPOINT"
            value = "http://minio.block-storage.svc.cluster.local"
          }

          env {
            name  = "AWS_ACCESS_KEY_ID"
            value = "admin"
          }

          env {
            name = "AWS_SECRET_ACCESS_KEY"
            value_from {
              secret_key_ref {
                name = "minio-secret"
                key  = "secretkey"
              }
            }
          }

          env {
            name  = "MINIO_REGION"
            value = "us-east-1"
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/ping"
              port = 8080

              http_header {
                name  = "X-Custom-Header"
                value = "Awesome"
              }
            }

            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "texura_engine_nodeport" {
  metadata {
    name      = "texture-engine"
    namespace = "default"
  }

  spec {
    selector = {
      test = "TextureEngine"
    }

    type = "ClusterIP"

    port {
      port        = 8080
      target_port = 8080
    }
  }
}
