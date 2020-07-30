output "id" {
  value       = aws_vpc.default.id
  description = "VPC ID"
}

output "primary_subnet_ids" {
  value       = aws_subnet.primary.*.id
  description = "List of public subnet IDs"
}

output "secondary_subnet_ids" {
  value       = aws_subnet.secondary.*.id
  description = "List of public subnet IDs"
}

output "primary_instance_ip" {
  value       = aws_eip.primary.*.public_ip
  description = "Elastic IPs of primary instance"
}

output "secondary_instance_ip" {
  value       = aws_eip.secondary.*.public_ip
  description = "Elastic IPs of primary instance"
}
