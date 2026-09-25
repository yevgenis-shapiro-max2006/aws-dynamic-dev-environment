
resource "helm_release" "minio" {
  name       = "minio"
  namespace  = "default"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "minio"
  version    = "14.6.18" # check latest stable version
  create_namespace = true

  values = [
    yamlencode({
      mode = "standalone" # or distributed
      defaultBuckets: "velero,airbyte,anythingllm,loki"
      replicas = 1

      auth = {
        rootUser     = "root"
        rootPassword = "q1w2e3r4100@" # ⚠️ replace with secret/variable
      }

      persistence = {
        enabled = true
        size    = "10Gi"
      }

      service = {
        type = "ClusterIP" # can be NodePort / LoadBalancer depending on infra
      }

      resources = {
        requests = {
          memory = "512Mi"
          cpu    = "250m"
        }
        limits = {
          memory = "1Gi"
          cpu    = "1000m"
        }
      }
    })
  ]
}
