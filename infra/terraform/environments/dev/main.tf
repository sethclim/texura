provider "minikube" {
  kubernetes_version = "v1.30.0"
}

resource "minikube_cluster" "docker" {
  driver       = "docker"
  cluster_name = "texura-dev"

  cpus   = 8
  memory = 20480

  addons = [
    "default-storageclass",
    "storage-provisioner",
    "ingress"
  ]
  gpus    = "nvidia"
  kvm_gpu = true
}

provider "kubernetes" {
  host = minikube_cluster.docker.host

  client_certificate     = minikube_cluster.docker.client_certificate
  client_key             = minikube_cluster.docker.client_key
  cluster_ca_certificate = minikube_cluster.docker.cluster_ca_certificate
}

resource "null_resource" "label_gpu_node" {
  provisioner "local-exec" {
    command = "kubectl label node texura-dev nvidia.com/gpu.present=true --overwrite"
  }

  depends_on = [minikube_cluster.docker]
}

resource "helm_release" "nvidia_device_plugin" {
  name       = "nvidia-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = "0.15.0"

  namespace  = "kube-system"
  depends_on = [null_resource.label_gpu_node]
}


# resource "kind_cluster" "this" {
#   name            = var.cluster_name
#   node_image      = "kindest/node:${var.cluster_version}"
#   kubeconfig_path = pathexpand(var.kubeconfig_file)
#   wait_for_ready  = true

#   kind_config {
#     kind        = "Cluster"
#     api_version = "kind.x-k8s.io/v1alpha4"

#     containerd_config_patches = [
#       <<-EOT
#       [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
#         endpoint = ["http://local-registry:5000"]
#       EOT
#     ]

#     node {
#       role = "control-plane"
#       extra_port_mappings {
#         container_port = 80
#         host_port      = var.host_port

#       }
#       extra_port_mappings {
#         container_port = 30080
#         host_port      = var.host_port_30080
#       }

#     }

#     node {
#       role = "worker"
#     }
#   }
# }

provider "helm" {
  kubernetes {
    config_path = pathexpand(var.kubeconfig_file)
  }
}

# provider "kubernetes" {
#   config_path = pathexpand(var.kubeconfig_file)
# }


resource "null_resource" "execute_python" {
  depends_on = [minikube_cluster.docker]
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command     = "python3 build_and_load_images.py"
    working_dir = "${path.module}/../../../scripts/"
  }
}


# # resource "kubernetes_config_map" "local_registry_hosting" {
# #   metadata {
# #     name      = "local-registry-hosting"
# #     namespace = "kube-public"
# #   }

# #   data = {
# #     "localRegistryHosting.v1" = <<-EOT
# #       host: "localhost:${var.reg_port}"
# #       help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
# #     EOT
# #   }
# # }

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
    name = "texura-api-deployment"
    labels = {
      test = "MyApp"
    }
  }

  depends_on = [null_resource.execute_python]

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
            name  = "RABBIT_MQ_ADDRESS"
            value = "amqp://user:password@rabbitmq.rabbitmq:5672/"
          }

          env {
            name  = "REDIS_ADDRESS"
            value = "redis-master:6379"
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
              cpu    = "1"
              memory = "1Gi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
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

# resource "kubernetes_service" "texura_api_nodeport" {
#   metadata {
#     name      = "texura-api"
#     namespace = "default"
#   }

#   spec {
#     selector = {
#       test = "MyApp" # this label must match your pod/deployment labels
#     }

#     type = "NodePort"

#     port {
#       port        = 7070  # service port inside the cluster
#       target_port = 7070  # container port your pod listens on
#       node_port   = 30080 # port exposed on the node (your local machine)
#       protocol    = "TCP"
#     }
#   }
# }

resource "kubernetes_service" "texura_api_nodeport" {
  metadata {
    name      = "texura-api"
    namespace = "default"
  }

  spec {
    selector = {
      test = "MyApp"
    }

    type = "ClusterIP"

    port {
      port        = 7070
      target_port = 7070
    }
  }
}


resource "kubernetes_ingress_v1" "example" {
  metadata {
    name = "example-ingress"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "texura-api"
              port {
                number = 7070
              }
            }
          }
        }
      }
    }
  }
}

resource "null_resource" "patch_ingress_nginx" {
  depends_on = [kubernetes_ingress_v1.example]
  provisioner "local-exec" {
    command = "kubectl patch svc ingress-nginx-controller -n ingress-nginx --type=merge --patch-file=patch-loadbalancer.json"
  }
}

resource "kubernetes_deployment" "test-deploy2" {
  metadata {
    name = "texture-engine-deployment"
    labels = {
      test = "TextureEngine"
    }
  }

  depends_on = [null_resource.execute_python]

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
            name  = "RABBIT_MQ_ADDRESS"
            value = "amqp://user:password@rabbitmq.rabbitmq:5672/"
          }

          env {
            name  = "REDIS_HOST"
            value = "redis-master"
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
              cpu              = "2"
              memory           = "8Gi"
              "nvidia.com/gpu" = "1"
            }
            requests = {
              cpu              = "2"
              memory           = "8Gi"
              "nvidia.com/gpu" = "1"
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
