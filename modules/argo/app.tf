
###---Application---###
resource "argocd_application" "minio" {
  metadata {
    name      = "minio"
    namespace = "argocd"
  }

  spec {
    project = "default"

    source {
      repo_url        = "https://github.com/bitnami/charts.git"
      target_revision = "HEAD"
      path            = "bitnami/minio"

      helm {
        values = <<EOF
auth:
  rootUser: root
  rootPassword: q1w2e3r4100@

defaultBuckets: "velero,terraform,loki"

persistence:
  enabled: true
  size: 10Gi

service:
  type: ClusterIP     

EOF
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "default"
    }

    sync_policy {
      automated {
        prune = true
        self_heal = true
      }
    }
  }
  depends_on = [argocd_application.prometheus]
}


###---Loki 
resource "argocd_application" "loki" {
  metadata {
    name      = "loki"
    namespace = "argocd"
  }

  spec {
    project = "default"

    source {
      repo_url        = "https://github.com/bitnami/charts.git"
      target_revision = "HEAD"
      path            = "bitnami/grafana-loki"

      helm {
        values = <<EOF
server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem: null
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2023-01-01
      store: boltdb-shipper
      object_store: s3
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  aws:
    s3: http://root:q1w2e3r4100@!@minio:9000/loki
    s3forcepathstyle: true
    insecure: true
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
    shared_store: s3

compactor:
  working_directory: /loki/compactor
  shared_store: s3

limits_config:
  retention_period: 168h  # keep logs 7 days   

EOF
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "default"
    }

    sync_policy {
      automated {
        prune = true
        self_heal = true
      }
    }
  }
  depends_on = [argocd_application.minio]
}
