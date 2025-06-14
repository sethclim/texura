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
    }

    node {
      role = "worker"
    }
  }
}

resource "kubernetes_config_map" "local_registry_hosting" {
  metadata {
    name      = "local-registry-hosting"
    namespace = "kube-public"
  }

  data = {
    "localRegistryHosting.v1" = <<-EOT
      host: "localhost:${var.reg_port}"
      help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
    EOT
  }
}


resource "kubernetes_deployment" "test-deploy" {
  metadata {
    name = "terraform"
    labels = {
      test = "MyApp"
    }
  }

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
          image = "texura-texura_api:latest"
          name  = "api"

          image_pull_policy = "IfNotPresent"

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
              path = "/"
              port = 80

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

# resource "kubernetes_deployment" "test-deploy2" {
#   metadata {
#     name = "textureapidep"
#     labels = {
#       test = "TextureApi"
#     }
#   }

#   spec {
#     replicas = 1

#     selector {
#       match_labels = {
#         test = "TextureApi"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           test = "TextureApi"
#         }
#       }

#       spec {
#         container {
#           image = "texura-texura_api::latest"
#           name  = "texura-api"

#           resources {
#             limits = {
#               cpu    = "0.5"
#               memory = "512Mi"
#             }
#             requests = {
#               cpu    = "250m"
#               memory = "50Mi"
#             }
#           }

#           liveness_probe {
#             http_get {
#               path = "/"
#               port = var.host_port

#               http_header {
#                 name  = "X-Custom-Header"
#                 value = "Awesome"
#               }
#             }

#             initial_delay_seconds = 3
#             period_seconds        = 3
#           }
#         }
#       }
#     }
#   }
# }
