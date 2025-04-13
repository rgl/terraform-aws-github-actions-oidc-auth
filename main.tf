terraform {
  required_version = "1.11.4"
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/aws
    # see https://github.com/hashicorp/terraform-provider-aws
    aws = {
      source  = "hashicorp/aws"
      version = "5.94.1"
    }
    # see https://registry.terraform.io/providers/integrations/github
    # see https://github.com/integrations/terraform-provider-github
    github = {
      source  = "integrations/github"
      version = "6.6.0"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
      Project = trim(var.name_prefix, "-")
    }
  }
}

provider "github" {
}

variable "github_repository_url" {
  type        = string
  description = "GitHub repository URL in format git@github.com:owner/repo.git or https://github.com/owner/repo"
  default     = "git@github.com:rgl/terraform-aws-github-actions-oidc-auth.git"
  validation {
    condition     = can(regex("^(git@github.com:|https://github.com/)[^/]+/[^/]+", var.github_repository_url))
    error_message = "Must be a valid GitHub URL: git@github.com:owner/repo.git or https://github.com/owner/repo"
  }
}

variable "region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "eu-west-1"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for all AWS resources"
  default     = "rgl-gha-oidc"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "Prefix must be lowercase alphanumeric characters or hyphens"
  }
}

locals {
  github_owner = regex("github.com[:/]([^/]+)", var.github_repository_url)[0]
  github_repo  = regex("github.com[:/][^/]+/([^/.]+)", var.github_repository_url)[0]

  iam_role_name = "${var.name_prefix}-${local.github_owner}-${local.github_repo}"
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
resource "aws_iam_role" "github" {
  name = local.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${local.github_owner}/${local.github_repo}:ref:refs/heads/main",
              "repo:${local.github_owner}/${local.github_repo}:ref:refs/heads/wip"
            ]
          }
        }
      }
    ]
  })
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment
resource "aws_iam_role_policy_attachment" "github" {
  role       = aws_iam_role.github.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# see https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_variable
resource "github_actions_variable" "aws" {
  for_each = {
    AWS_ROLE_ARN = aws_iam_role.github.arn
    AWS_REGION   = var.region
  }
  repository    = local.github_repo
  variable_name = each.key
  value         = each.value
}
