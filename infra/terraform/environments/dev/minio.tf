resource "helm_release" "minio_operator" {
  name              = "minio-operator"
  chart             = "operator"
  repository        = "https://operator.min.io/"
  create_namespace  = "true"
  namespace         = "minio-operator"
  dependency_update = "true"
  version           = "5.0.18"

  depends_on = [minikube_cluster.docker]
}

resource "random_password" "minio" {
  length = 16
}

resource "kubernetes_namespace" "tenant" {
  metadata {
    name = "block-storage"
  }
}

resource "kubernetes_secret" "minio_secret" {
  metadata {
    name      = "minio-secret"
    namespace = kubernetes_namespace.tenant.metadata.0.name
  }

  data = {
    accesskey = "admin"
    secretkey = random_password.minio.result
  }

  type = "Opaque"
}

resource "kubectl_manifest" "tenant" {
  yaml_body = file("../../../../infra/k8s/manifests/minio-tenant.yaml")
  depends_on = [
    kubernetes_secret.minio_secret
  ]
}

resource "kubectl_manifest" "create_bucket" {
  yaml_body = file("../../../../infra/k8s/manifests/minio-bucket.yaml")
  force_new = true
  wait      = true
  depends_on = [
    kubectl_manifest.tenant
  ]
}

