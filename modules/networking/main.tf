# ---------------------------------------------------------------------------
# Hub network: holds the shared Azure Firewall and the VPN gateway.
# All spoke egress is force-tunnelled through the firewall (see route table).
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "hub" {
  name                = "${var.prefix}-hub-vnet"
  location            = var.location
  resource_group_name = var.hub_resource_group
  address_space       = [var.hub_address_space]
  tags                = var.tags
}

# Subnet name MUST be exactly "AzureFirewallSubnet" or the firewall will not deploy.
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.hub_resource_group
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_space, 10, 0)] # /26
}

# Subnet name MUST be exactly "GatewaySubnet" for the VPN gateway.
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.hub_resource_group
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_address_space, 11, 2)] # /27
}

# ---------------------------------------------------------------------------
# Azure Firewall + policy
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "firewall" {
  name                = "${var.prefix}-fw-pip"
  location            = var.location
  resource_group_name = var.hub_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "hub" {
  name                = "${var.prefix}-fw-policy"
  location            = var.location
  resource_group_name = var.hub_resource_group
  sku                 = "Standard"
  tags                = var.tags
}

# A minimal egress ruleset: allow HTTPS out, deny the rest by default.
resource "azurerm_firewall_policy_rule_collection_group" "egress" {
  name               = "egress"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 500

  network_rule_collection {
    name     = "allow-https-out"
    priority = 400
    action   = "Allow"

    rule {
      name                  = "https"
      protocols             = ["TCP"]
      source_addresses      = [for s in var.spokes : s.workload_cidr]
      destination_addresses = ["*"]
      destination_ports     = ["443"]
    }
  }
}

resource "azurerm_firewall" "hub" {
  name                = "${var.prefix}-fw"
  location            = var.location
  resource_group_name = var.hub_resource_group
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.hub.id
  tags                = var.tags

  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# ---------------------------------------------------------------------------
# VPN gateway (route-based). Provisioning is slow: see the runbook in README.
# ---------------------------------------------------------------------------

resource "azurerm_public_ip" "gateway" {
  name                = "${var.prefix}-gw-pip"
  location            = var.location
  resource_group_name = var.hub_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "hub" {
  name                = "${var.prefix}-vpn-gw"
  location            = var.location
  resource_group_name = var.hub_resource_group
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  tags                = var.tags

  ip_configuration {
    name                          = "vnetGatewayConfig"
    subnet_id                     = azurerm_subnet.gateway.id
    public_ip_address_id          = azurerm_public_ip.gateway.id
    private_ip_address_allocation = "Dynamic"
  }
}

# ---------------------------------------------------------------------------
# Route table: force every spoke's default route through the firewall.
# ---------------------------------------------------------------------------

resource "azurerm_route_table" "spoke_egress" {
  name                = "${var.prefix}-spoke-rt"
  location            = var.location
  resource_group_name = var.spoke_resource_group
  tags                = var.tags

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
  }
}

# ---------------------------------------------------------------------------
# Spokes: one VNet + workload subnet + NSG each, peered both ways to the hub.
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "spoke" {
  for_each = var.spokes

  name                = "${var.prefix}-${each.key}-vnet"
  location            = var.location
  resource_group_name = var.spoke_resource_group
  address_space       = [each.value.address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "workload" {
  for_each = var.spokes

  name                 = "workload"
  resource_group_name  = var.spoke_resource_group
  virtual_network_name = azurerm_virtual_network.spoke[each.key].name
  address_prefixes     = [each.value.workload_cidr]
}

resource "azurerm_network_security_group" "workload" {
  for_each = var.spokes

  name                = "${var.prefix}-${each.key}-nsg"
  location            = var.location
  resource_group_name = var.spoke_resource_group
  tags                = var.tags

  security_rule {
    name                       = "deny-inbound-internet"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "workload" {
  for_each = var.spokes

  subnet_id                 = azurerm_subnet.workload[each.key].id
  network_security_group_id = azurerm_network_security_group.workload[each.key].id
}

resource "azurerm_subnet_route_table_association" "workload" {
  for_each = var.spokes

  subnet_id      = azurerm_subnet.workload[each.key].id
  route_table_id = azurerm_route_table.spoke_egress.id
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spokes

  name                      = "hub-to-${each.key}"
  resource_group_name       = var.hub_resource_group
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke[each.key].id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = var.spokes

  name                      = "${each.key}-to-hub"
  resource_group_name       = var.spoke_resource_group
  virtual_network_name      = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
  use_remote_gateways       = false
}
