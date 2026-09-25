
resource "helm_release" "velero" {
  name             = "velero"
  namespace        = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  version          = "6.7.0" # check latest
  create_namespace = true

  values = [<<EOF
configuration:
  #provider: aws

  backupStorageLocation:
    - name: default
      provider: aws
      bucket: velero
      config:
        region: us-west-rack2
        s3ForcePathStyle: "true"
        s3Url: "http://minio.default.svc.cluster.local:9000"

  volumeSnapshotLocation:
    - name: default
      provider: aws
      config:
        region: us-west-rack2

credentials:
  useSecret: true
  secretContents:
    cloud: |
      [default]
      aws_access_key_id = root
      aws_secret_access_key = q1w2e3r4100@

initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.8.0
    volumeMounts:
      - mountPath: /target
        name: plugins

metrics:
  enabled: true

deployNodeAgent: true
EOF
  ]
}
