provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  filter {
    name = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {
}

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.39.0-eksbuild.1"
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    eks_addon = "ebs-csi"
    terraform = "true"
    scoutflo-terraform = "true"
  }

  depends_on = [module.eks]
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name      = module.eks.cluster_name
  addon_name        = "kube-proxy"
  addon_version     = "v1.31.3-eksbuild.2"
  resolve_conflicts = "OVERWRITE"
  tags = {
    eks_addon = "kube-proxy"
    terraform = "true"
    scoutflo-terraform = "true"
  }

  depends_on = [module.eks]
}

resource "aws_eks_addon" "vpc-cni" {
  cluster_name      = module.eks.cluster_name
  addon_name        = "vpc-cni"
  addon_version     = "v1.19.2-eksbuild.1"
  resolve_conflicts = "OVERWRITE"
  tags = {
    eks_addon = "vpc-cni"
    terraform = "true"
    scoutflo-terraform = "true"
  }

  depends_on = [module.eks]
}

resource "aws_eks_addon" "coredns" {
  cluster_name      = module.eks.cluster_name
  addon_name        = "coredns"
  addon_version     = "v1.11.4-eksbuild.2"
  resolve_conflicts = "OVERWRITE"
  tags = {
    eks_addon = "coredns"
    terraform = "true"
    scoutflo-terraform = "true"
  }

  depends_on = [module.eks]
}

resource "aws_ec2_tag" "tag_subnet0_cluster" {
  resource_id = "subnet-0292076ffac71c626"
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "tag_subnet0_elb" {
  resource_id = "subnet-0292076ffac71c626"
  key         = "kubernetes.io/role/elb"
  value       = 1
}

resource "aws_ec2_tag" "tag_subnet1_cluster" {
  resource_id = "subnet-0f54f7f1051b8404e"
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "tag_subnet1_elb" {
  resource_id = "subnet-0f54f7f1051b8404e"
  key         = "kubernetes.io/role/elb"
  value       = 1
}

resource "aws_ec2_tag" "tag_subnet2_cluster" {
  resource_id = "subnet-0fccf4f22702bdebd"
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "tag_subnet2_elb" {
  resource_id = "subnet-0fccf4f22702bdebd"
  key         = "kubernetes.io/role/elb"
  value       = 1
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "19.5.1"
  cluster_name    = var.cluster_name
  cluster_version = "1.32"
  vpc_id          = "vpc-055cd949cc1ca7ffe"
  subnet_ids = [
    "subnet-0292076ffac71c626",
    "subnet-0f54f7f1051b8404e",
    "subnet-0fccf4f22702bdebd"
  ]

  cluster_endpoint_public_access = true
  
  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
    name_prefix = "eks-nodegroup-"
  }

  eks_managed_node_groups = {
    one = {
      name = "one"
      instance_types = [var.instance_type]
      min_size     = var.min_size
      max_size     = var.max_size
      desired_size = var.desired_size
      capacity_type = "ON_DEMAND"
    }
  }

  tags = {
    scoutflo-terraform = "true"
  }
}

module "irsa-ebs-csi" {
  source       = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version      = "5.34.0"
  create_role  = true
  role_name    = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url = module.eks.oidc_provider
  role_policy_arns = [
    data.aws_iam_policy.ebs_csi_policy.arn
  ]

  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:ebs-csi-controller-sa"
  ]

  tags = {
    scoutflo-terraform = "true"
  }
}
