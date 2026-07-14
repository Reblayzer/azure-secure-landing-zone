variable "prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "hub_resource_group" {
  type = string
}

variable "spoke_resource_group" {
  type = string
}

variable "hub_address_space" {
  type = string
}

variable "spokes" {
  type = map(object({
    address_space = string
    workload_cidr = string
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
