output "instance_hostname" {
  description = "The public DNS name of the web server instance"
  value       = aws_instance.app_server.private_dns
}
