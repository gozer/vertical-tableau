output "address" {
  value = "https://${module.dns.fqdn}/"
}

output "psql" {
  value = "psql://${module.dns_psql.fqdn}:${local.psql_port}"
}
