output "instance_public_ip" {
  value = aws_eip.flask_eip.public_ip
}

output "instance_public_dns" {
  value = aws_instance.flask_app.public_dns
}

output "ssh_private_key_pem" {
  description = "Private key material for ssh (useful in dev). Don't commit state with secrets in it for production."
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}