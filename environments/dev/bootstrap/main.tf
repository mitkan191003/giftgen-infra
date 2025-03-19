provider "aws" {
  region = var.region
}

data "terraform_remote_state" "core" {
  backend = "s3"
  config = {
    bucket  = var.state_bucket_name
    key     = var.core_state_key
    region  = var.region
    encrypt = true
  }
}

data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.core.outputs.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.core.outputs.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

module "cluster_bootstrap" {
  source = "../../../modules/cluster_bootstrap"
}
