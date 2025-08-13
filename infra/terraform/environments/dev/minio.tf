resource "helm_release" "minio" {
  name       = "minio"
  namespace  = "default"
  repository = "https://charts.min.io/"
  chart      = "minio"
  version    = "5.0.14"

  set {
    name  = "mode"
    value = "standalone"
  }

  set {
    name  = "rootUser"
    value = "minio"
  }

  set {
    name  = "rootPassword"
    value = "minio123"
  }

  set {
    name  = "persistence.enabled"
    value = "false"
  }

  set {
    name  = "console.enabled"
    value = "true"
  }

  set {
    name  = "resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "service.type"
    value = "NodePort"
  }

  set {
    name  = "postJob.enabled"
    value = "true"
  }

  set {
    name  = "buckets[0].name"
    value = "my-bucket"
  }

  set {
    name  = "buckets[0].policy"
    value = "download"
  }

  set {
    name  = "env[0].name"
    value = "MINIO_REGION"
  }

  set {
    name  = "env[0].value"
    value = "us-east-1"
  }

  # set {
  #   name  = "browserRedirectUrl"
  #   value = "http://${data.external.minikube_ip.result["ip"]}/minio"
  # }

}
