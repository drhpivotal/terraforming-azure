output "cidr" {
  value = "${var.cidr}"
}

output "postgres_fqdn" {
  value = "${azurerm_postgresql_server.plane.fqdn}"
}

output "postgres_password" {
  value = "${random_string.postgres_password.result}"
}

output "postgres_username" {
  value = "${var.postgres_username}"
}
