# Reuse the active deployment's state; do not copy state into this directory.
# Run from the repository root with terraform -chdir=terraform/layer4.
terraform {
  backend "local" {
    path = "../layer2/terraform.tfstate"
  }
}

