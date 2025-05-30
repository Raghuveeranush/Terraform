
/*
resource "aws_vpc" "main-vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    "Name" = "Hackthon-vpc"
  }
}

resource "aws_subnet" "public-subnet" {
  vpc_id = aws_vpc.main-vpc.id
  cidr_block = var.public_subnet

  tags = {
    "Name" = "Dev-public-subent"
  }
}

resource "aws_subnet" "private_subent" {
  vpc_id = aws_vpc.main-vpc
  cidr_block = var.public_subnet

  tags = {
    "Name" = "private-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main-vpc.id
  tags = {
    "Name" = "dev-Igw"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.main-vpc.id

    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }
}
resource "aws_route_table_association" "associate_rt" {
  subnet_id = aws_subnet.public-subnet.id
  route_table_id = aws_subnet.public-subnet.id
}

resource "aws_eip" "eip" {
  domain = vpc
}

resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.eip.allocation_id
  subnet_id = aws_subnet.public-subnet.id
}

resource "aws_subnet" "pvt-subent" {
  cidr_block = var.private_subnet
  vpc_id = aws_vpc.main-vpc.id
  tags = {
    "Name" = "pvt-subnet"
  }  
}

resource "aws_route_table" "pvt-rt" {
  vpc_id = aws_vpc.main-vpc.id

    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "name" {
  subnet_id = aws_subnet.private_subent.id
  route_table_id = aws_subnet.private_subent.id
}

*/

# spining up eks cluster

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.29.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  eks_managed_node_group_defaults = {
    disk_size = 50
  }

  eks_managed_node_groups = {
    general = {
      desired_size = 1
      min_size     = 1
      max_size     = 10

      labels = {
        role = "general"
      }

      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"
    }

    spot = {
      desired_size = 1
      min_size     = 1
      max_size     = 10

      labels = {
        role = "spot"
      }

      taints = [{
        key    = "market"
        value  = "spot"
        effect = "NO_SCHEDULE"
      }]

      instance_types = ["t3.micro"]
      capacity_type  = "SPOT"
    }
  }

  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = module.eks_admins_iam_role.iam_role_arn
      username = module.eks_admins_iam_role.iam_role_name
      groups   = ["system:masters"]
    },
  ]

  node_security_group_additional_rules = {
    ingress_allow_access_from_control_plane = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }
  }

  tags = {
    Environment = "dev"
  }
}


data "aws_eks_cluster" "default" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "default" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.default.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
  # token                  = data.aws_eks_cluster_auth.default.token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.default.id]
    command     = "aws"
  }
}
