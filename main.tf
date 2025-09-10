provider "aws" {
  region = "your_region"
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"
  name    = "scoutflo-vpc-${random_string.suffix.result}"
  cidr    = "10.0.0.0/16"
  azs     = slice(data.aws_availability_zones.available.names, 0, min(3, length(data.aws_availability_zones.available.names)))
  public_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_dns_hostnames = true
  public_subnet_tags = {
    "kubernetes.io/cluster/your_cluster_name" = "shared"
    "kubernetes.io/role/elb"                  = 1
  }
  tags = {
    "scoutflo-terraform" = "true"
  }
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "19.5.1"
  cluster_name    = "mycluster"
  cluster_version = "1.32"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnets
  cluster_endpoint_public_access = true
  eks_managed_node_group_defaults = { 
    ami_type   = "AL2_x86_64"
    name_prefix = "eks-nodegroup-"
  }
  eks_managed_node_groups = {
    one = {
      name           = "node-group-1"
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 5
      desired_size   = 3
      capacity_type  = "ON_DEMAND"
    }
  }
  tags = {
    "scoutflo-terraform" = "true"
  }
}

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.34.0"
  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
  tags = {
    "scoutflo-terraform" = "true"
  }
}

resource "aws_eks_addon" "ebs-csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.39.0-eksbuild.1"
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon"         = "ebs-csi"
    "terraform"         = "true"
    "scoutflo-terraform" = "true"
  }
  depends_on = [module.eks]
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name      = module.eks.cluster_name
  addon_name        = "kube-proxy"
  addon_version     = "v1.31.3-eksbuild.2"
  resolve_conflicts = "OVERWRITE"
  tags = {
    "eks_addon"         = "kube-proxy"
    "terraform"         = "true"
    "scoutflo-terraform" = "true"
  }
  depends_on = [module.eks]
}

resource "aws_eks_addon" "vpc-cni" {
  cluster_name      = module.eks.cluster_name
  addon_name        = "vpc-cni"
  addon_version     = "v1.19.2-eksbuild.1"
  resolve_conflicts = "OVERWRITE"
  tags = {
    "eks_addon"         = "vpc-cni"
    "terraform"         = "true"
    "scoutflo-terraform" = "true"
  }
  depends_on = [module.eks]
}

resource "aws_eks_addon" "coredns" {
  cluster_name      = module.eks.cluster_name
  addon_name        = "coredns"
  addon_version     = "v1.11.4-eksbuild.2"
  resolve_conflicts = "OVERWRITE"
  tags = {
    "eks_addon"         = "coredns"
    "terraform"         = "true"
    "scoutflo-terraform" = "true"
  }
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_name
}

module "storage_class" {
  source = "./modules/kubernetes-storage-class"
  depends_on = [module.eks]
  providers = {
    kubernetes = kubernetes
  }
}
