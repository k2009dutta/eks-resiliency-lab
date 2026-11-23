
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.30.2"

  name               = "${var.project_name}-cluster"
  kubernetes_version = "1.33"

  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  node_security_group_additional_rules = {
    ingress_nodes_http = {
      description = "Allow HTTP between EKS worker nodes"
      protocol    = "tcp"
      from_port   = 80
      to_port     = 80
      type        = "ingress"
      self        = true
    }
  }
  eks_managed_node_groups = {
    node_az_a = {
      name           = "resilience-node-az-a"
      subnet_ids     = [module.vpc.private_subnets[0]]
      instance_types = ["t3.medium"]
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size     = 1
      max_size     = 1
      desired_size = 1
    }

    node_az_b = {
      name           = "resilience-node-az-b"
      subnet_ids     = [module.vpc.private_subnets[1]]
      instance_types = ["t3.medium"]
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }

  tags = local.tags
}
