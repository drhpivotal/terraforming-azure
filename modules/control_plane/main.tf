locals {
  name_prefix = "${var.env_name}-plane"
  web_ports   = [80, 443, 8443, 8844, 2222]
  databases = ["uaa", "credhub", "atc"]
}

# DNS

resource "azurerm_dns_a_record" "plane" {
  resource_group_name = "${var.resource_group_name}"
  name                = "${local.name_prefix}-dns-record"
  zone_name           = "${var.dns_zone_name}"
  ttl                 = "60"
  records             = ["${azurerm_public_ip.plane.ip_address}"]
}

# Load Balancers

resource "azurerm_public_ip" "plane" {
  resource_group_name          = "${var.resource_group_name}"
  name                         = "${local.name_prefix}-ip"
  location                     = "${var.location}"
  public_ip_address_allocation = "static"
  sku                          = "Standard"
}

resource "azurerm_lb" "plane" {
  resource_group_name = "${var.resource_group_name}"
  name                = "${var.env_name}-lb"
  location            = "${var.location}"

  frontend_ip_configuration {
    name                 = "${local.name_prefix}-ip"
    public_ip_address_id = "${azurerm_public_ip.plane.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "plane" {
  resource_group_name = "${var.resource_group_name}"
  name                = "${local.name_prefix}-pool"
  loadbalancer_id     = "${azurerm_lb.plane.id}"
}

resource "azurerm_lb_probe" "plane" {
  resource_group_name = "${var.resource_group_name}"
  count               = "${length(local.web_ports)}"
  name                = "${local.name_prefix}-${element(local.web_ports, count.index)}-probe"

  port     = "${element(local.web_ports, count.index)}"
  protocol = "Tcp"

  loadbalancer_id     = "${azurerm_lb.plane.id}"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "plane" {
  resource_group_name = "${var.resource_group_name}"
  count               = "${length(local.web_ports)}"
  name                = "${local.name_prefix}-${element(local.web_ports, count.index)}"

  protocol                       = "Tcp"
  loadbalancer_id                = "${azurerm_lb.plane.id}"
  frontend_port                  = "${element(local.web_ports, count.index)}"
  backend_port                   = "${element(local.web_ports, count.index)}"
  frontend_ip_configuration_name = "${azurerm_public_ip.plane.name}"
  probe_id                       = "${element(azurerm_lb_probe.plane.*.id, count.index)}"
}

# Firewall

resource "azurerm_network_security_group" "plane" {
  name                = "${local.name_prefix}-${element(local.web_ports, count.index)}-security-group"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"

  security_rule {
    name                       = "${local.name_prefix}-${element(local.web_ports, count.index)}"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "${element(local.web_ports, count.index)}"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network

resource "azurerm_subnet" "plane" {
  name                 = "${local.name_prefix}-subnet"
  resource_group_name  = "${var.resource_group_name}"
  virtual_network_name = "${var.network_name}"
  address_prefix       = "${var.cidr}"
}

# Database

resource "azurerm_postgresql_server" "plane" {
  name = "${local.name_prefix}-postgres"
  resource_group_name = "${var.resource_group_name}"
  location            = "${var.location}"

  sku {
    name = "B_Gen4_2"
    capacity = 2
    tier = "Basic"
    family = "Gen4"
  }

  storage_profile {
    storage_mb = 10240
    backup_retention_days = 7
    geo_redundant_backup = "Disabled"
  }

  administrator_login = "${var.postgres_username}"
  administrator_login_password = "${random_string.postgres_password.result}"
  version = "9.6"
  ssl_enforcement = "Enabled"
}

resource "azurerm_postgresql_database" "plane" {
  resource_group_name = "${var.resource_group_name}"
  name = "${element(local.databases, count.index)}"

  server_name = "${azurerm_postgresql_server.plane.name}"
  charset = "UTF8"
  collation = "English_United States.1252"
}

resource "random_string" "postgres_password" {
  length  = 16
  special = false
}
