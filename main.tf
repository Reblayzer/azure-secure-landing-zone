resource "azurerm_resource_group" "hub" {
  name     = "${var.prefix}-hub-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "spokes" {
  name     = "${var.prefix}-spokes-rg"
  location = var.location
  tags     = var.tags
}

module "networking" {
  source = "./modules/networking"

  prefix               = var.prefix
  location             = var.location
  hub_resource_group   = azurerm_resource_group.hub.name
  spoke_resource_group = azurerm_resource_group.spokes.name
  hub_address_space    = var.hub_address_space
  spokes               = var.spokes
  tags                 = var.tags
}
