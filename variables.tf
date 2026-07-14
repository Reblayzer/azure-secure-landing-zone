variable "subscription_id" {
  description = "Azure subscription ID. Not needed for `terraform validate`; required for plan/apply."
  type        = string
  default     = null
}

variable "prefix" {
  description = "Short name prefix for all resources (lowercase, no spaces)."
  type        = string
  default     = "aslz"
}

variable "location" {
  description = "Azure region for the landing zone."
  type        = string
  default     = "westeurope"
}

variable "tags" {
  description = "Tags applied to every resource group."
  type        = map(string)
  default = {
    project = "azure-secure-landing-zone"
    managed = "terraform"
  }
}

variable "hub_address_space" {
  description = "CIDR for the hub virtual network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "spokes" {
  description = "Spoke networks, keyed by name. Each gets a VNet, a workload subnet, an NSG and a route table that forces egress through the hub firewall."
  type = map(object({
    address_space = string
    workload_cidr = string
  }))
  default = {
    app = {
      address_space = "10.1.0.0/16"
      workload_cidr = "10.1.1.0/24"
    }
    data = {
      address_space = "10.2.0.0/16"
      workload_cidr = "10.2.1.0/24"
    }
  }
}
