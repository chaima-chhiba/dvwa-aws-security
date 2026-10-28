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
    1. bash scripts/push-image.sh      (only if the ECR repo is empty)
    2. bash scripts/task-ip.sh         (prints the public URL of DVWA)
    3. open http://<ip>/setup.php, click "Create / Reset Database", then log in admin / password
  EOT
}
