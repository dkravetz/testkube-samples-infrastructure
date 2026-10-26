# One EKS cluster with Argo CD in it. Argo CD runs one ApplicationSet, "addons", that turns
# every directory under gitops_addons_path into an Application (namespace = directory name), so
# everything else in the cluster comes from git.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.29"

  name               = var.name
  kubernetes_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  endpoint_public_access = true
  enable_irsa            = var.enable_irsa

  enable_cluster_creator_admin_permissions = true
  access_entries                           = var.access_entries
}
