# The subscription_id is required by the azurerm v4 provider for plan/apply.
# `terraform validate` does not need it, so CI can validate with no credentials.
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {}
