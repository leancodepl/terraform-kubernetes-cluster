# Root module - disable legacy provider format warning
# Provider constraints use simplified syntax for Terragrunt compatibility
rule "terraform_required_providers" {
  enabled = false
}

