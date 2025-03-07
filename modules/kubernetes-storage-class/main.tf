resource "kubernetes_storage_class" "this" {
  metadata {
    name = "gp3-csi"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com" # Correct argument name
  volume_binding_mode = "WaitForFirstConsumer"
  reclaim_policy      = "Delete"

  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }

}
