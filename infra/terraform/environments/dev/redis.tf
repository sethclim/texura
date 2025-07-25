resource "helm_release" "redis" {
  name    = "redis"
  chart   = "oci://registry-1.docker.io/bitnamicharts/redis"
  version = "21.2.13"

  namespace = "default"

  set {
    name  = "auth.enabled"
    value = "false"
  }

  set {
    name  = "architecture"
    value = "standalone"
  }

  # Optional: expose a service type
  set {
    name  = "master.service.type"
    value = "ClusterIP"
  }
}
