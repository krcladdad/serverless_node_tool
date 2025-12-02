output "api_base_url" {
  value = "https://${aws_api_gateway_rest_api.my_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.dev_stage.stage_name}"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.image_bucket.bucket
}

output "dynamodb_note_table_name" {
  value = aws_dynamodb_table.note_table.name
}

output "dynamodb_contactus_table_name" {
  value = aws_dynamodb_table.contactus_table.name
}

output "instance_public_ip" {
  value = aws_eip.flask_eip.public_ip
}

output "instance_public_dns" {
  value = aws_instance.flask_serverless_app.public_dns
}

output "ssh_private_key_pem" {
  description = "Private key material for ssh (useful in dev). Don't commit state with secrets in it for production."
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}