output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "Public ALB hostname. Use HTTPS for application access."
}

output "ecr_repository_url" {
  value = aws_ecr_repository.dvwa.repository_url
}

output "rds_endpoint" {
  value = aws_db_instance.dvwa.address
}

output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "service_name" {
  value = aws_ecs_service.dvwa.name
}

output "next_steps" {
  value = <<-EOT
    Validate HTTP redirects to HTTPS and HTTPS /login.php returns 200.
    The lab certificate is self-signed; public certificate trust is not established.
    TLS terminates at the ALB. ALB-to-application traffic remains HTTP inside the VPC.
    Layer 3 adds regional WAF managed rules; save sanitized evidence in evidence/03-waf/.
  EOT
}

