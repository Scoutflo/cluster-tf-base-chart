resource "kubernetes_storage_class" "this" {
  metadata {
    name = "gp3-csi"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"  # ✅ Enable encryption
    fsType    = "ext4"
  }
}
