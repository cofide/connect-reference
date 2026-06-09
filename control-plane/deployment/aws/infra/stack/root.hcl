locals {
  # Strictly load the global config from the root directory
  root_dir    = get_parent_terragrunt_dir()
  root_config = read_terragrunt_config("${local.root_dir}/common.local.hcl")

  aws_account_id         = local.root_config.locals.aws_account_id
  aws_region             = local.root_config.locals.aws_region
  tf_state_bucket_region = local.root_config.locals.tf_state_bucket_region
  tf_state_bucket_name   = local.root_config.locals.tf_state_bucket_name
  tf_state_key_prefix    = local.root_config.locals.tf_state_key_prefix
  tf_state_key           = "${local.tf_state_key_prefix}/${path_relative_to_include()}/tf.tfstate"

  repo_root      = get_repo_root()
  stack_in_repo  = trimprefix(local.root_dir, "${local.repo_root}/")
  unit_repo_path = "${local.stack_in_repo}/${path_relative_to_include()}"
}

generate "aws_provider" {
  path      = "aws_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  # Guard to stop this being applied to another region by mistake
  region = "${local.aws_region}"
  # Guard to stop this being applied to another account by mistake
  allowed_account_ids = ["${local.aws_account_id}"]
  # Useful tags to identify the IaC source code behind infrastructure
  default_tags {
    tags = {
      ManagedBy      = "Terraform"
      Repository     = "github.com/cofide/connect-reference"
      RepositoryPath = "${local.unit_repo_path}"
    }
  }
}
EOF
}

remote_state {
  backend = "s3"
  config = {
    encrypt      = true
    bucket       = local.tf_state_bucket_name
    key          = local.tf_state_key
    region       = local.tf_state_bucket_region
    use_lockfile = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}
