

###---Monitoring---###
resource "argocd_application" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "argocd"
  }

  spec {
    project = "default"

    source {
      repo_url        = "https://github.com/bitnami/charts.git"
      target_revision = "HEAD"
      path            = "bitnami/grafana"
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
}


resource "argocd_application" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = "argocd"
  }

  spec {
    project = "default"

    source {
      repo_url        = "https://github.com/bitnami/charts.git"
      target_revision = "HEAD"
      path            = "bitnami/prometheus"

      helm {
        values = <<EOF
alertmanager:
  enabled: false

pushgateway:
  enabled: true
  service:
    port: 9091

serviceMonitor:
  enabled: true

server:
  retention: "10d"
  global:
    scrape_interval: 15s
    evaluation_interval: 15s
  service:
    type: ClusterIP

  extraScrapeConfigs:
    - job_name: 'argocd'
      metrics_path: /metrics
      static_configs:
        - targets: ['argocd-metrics.argocd.svc.cluster.local:8082']

    - job_name: 'velero'
      metrics_path: /metrics
      static_configs:
        - targets: ['velero.velero.svc.cluster.local:8085']

    - job_name: 'minio'
      metrics_path: /minio/v2/metrics/cluster
      static_configs:
        - targets: ['minio.default.svc.cluster.local:9000']

    - job_name: 'keda'
      metrics_path: /metrics
      static_configs:
        - targets: ['keda-operator.keda.svc.cluster.local:8080']

    - job_name: 'node-exporter'
      kubernetes_sd_configs:
        - role: node
      relabel_configs:
        - action: replace
          source_labels: [__address__]
          regex: (.+):10250
          replacement: ${1}:9100
          target_label: __address__

EOF
      }
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "default"
    }

    sync_policy {
      automated {
        prune     = true
        self_heal = true
      }
    }
  }
  depends_on = [argocd_application.grafana]
}


resource "argocd_application" "node-exporter" {
  metadata {
    name      = "node-exporter"
    namespace = "argocd"
  }

  spec {
    project = "default"

    source {
      repo_url        = "https://github.com/bitnami/charts.git"
      target_revision = "HEAD"
      path            = "bitnami/node-exporter"
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
}

