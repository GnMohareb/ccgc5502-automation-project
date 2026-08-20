output "lb_name" {
  description = "Name of the load balancer."
  value       = azurerm_lb.lb.name
}

output "lb_public_ip" {
  description = "Public IP address of the load balancer frontend."
  value       = azurerm_public_ip.lb_pip.ip_address
}

output "lb_fqdn" {
  description = "FQDN of the load balancer frontend."
  value       = azurerm_public_ip.lb_pip.fqdn
}
