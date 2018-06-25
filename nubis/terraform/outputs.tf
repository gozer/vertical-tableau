output "address" {
  value = "https://${aws_route53_record.primary.fqdn}/"
}
