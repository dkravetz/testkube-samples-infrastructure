# Run by Terrakube's app-bootstrap workspace (stacks/terrakube). Terrakube adds the state
# backend; the terrakube provider reads TERRAKUBE_ENDPOINT and TERRAKUBE_TOKEN from the
# workspace's environment.
terraform {
  required_version = "~> 1.13"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
    terrakube = {
      source  = "azbuilder/terrakube"
      version = "~> 0.29"
    }
  }
}

provider "github" {
  owner = "dkravetz"
  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_pem
  }
}
