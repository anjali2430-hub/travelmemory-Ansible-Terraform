output "web_public_ip" {
  description = "Public (Elastic) IP of the web server"
  value       = aws_eip.web.public_ip
}

output "app_url" {
  description = "URL of the TravelMemory app once Ansible has run"
  value       = "http://${aws_eip.web.public_ip}"
}

output "web_private_ip" {
  value = aws_instance.web.private_ip
}

output "db_private_ip" {
  value = aws_instance.db.private_ip
}

output "nat_gateway_public_ip" {
  value = aws_eip.nat.public_ip
}

output "ssh_web" {
  description = "SSH into the web server"
  value       = "ssh -i ansible/keys/${var.project_name}-key.pem ubuntu@${aws_eip.web.public_ip}"
}

output "ssh_db" {
  description = "SSH into the DB server through the web server"
  value       = "ssh -i ansible/keys/${var.project_name}-key.pem -J ubuntu@${aws_eip.web.public_ip} ubuntu@${aws_instance.db.private_ip}"
}
