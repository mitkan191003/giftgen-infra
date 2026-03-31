region      = "us-east-1"
project     = "giftgen"
environment = "prod"

cluster_version             = "1.33"
cluster_public_access_cidrs = ["0.0.0.0/0"] # Replace with restricted admin CIDRs for production.

vpc_cidr            = "10.30.0.0/16"
azs                 = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnets      = ["10.30.0.0/20", "10.30.16.0/20", "10.30.32.0/20"]
private_subnets     = ["10.30.128.0/20", "10.30.144.0/20", "10.30.160.0/20"]
node_instance_types = ["t4g.small"]
node_ami_type       = "AL2023_ARM_64_STANDARD"
node_desired_size   = 3
node_min_size       = 3
node_max_size       = 6

db_name                  = "giftgen"
db_username              = "giftgen"
db_instance_class        = "db.t3.micro"
db_allocated_storage     = 10
db_max_allocated_storage = 10
db_multi_az              = false
backup_retention_period  = 0
deletion_protection      = false

cloudflare_zone_id    = "42d2a162cb41b523b36daa21f60029a3"
frontend_hostname     = "giftgen.mithrak.com"
frontend_cname_target = "a3f15c3e4dcb2fb9.vercel-dns-017.com."
api_hostname          = "api-giftgen.mithrak.com"
argocd_hostname       = "argocd-giftgen.mithrak.com"
cognito_domain_prefix = "giftgen-prod-auth-mithrak"

cognito_callback_urls = [
  "https://giftgen.mithrak.com/auth/callback"
]

cognito_logout_urls = [
  "https://giftgen.mithrak.com"
]

cognito_password_minimum_length    = 7
cognito_password_require_lowercase = false
cognito_password_require_uppercase = false
cognito_password_require_numbers   = true
cognito_password_require_symbols   = false
