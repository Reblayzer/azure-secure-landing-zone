output "hub_vnet_id" {
  description = "Resource ID of the hub virtual network."
  value       = module.networking.hub_vnet_id
}

output "firewall_private_ip" {
  description = "Private IP of the Azure Firewall (the next hop for all spoke egress)."
  value       = module.networking.firewall_private_ip
}

output "spoke_vnet_ids" {
  description = "Resource IDs of the spoke virtual networks, keyed by spoke name."
  value       = module.networking.spoke_vnet_ids
}
