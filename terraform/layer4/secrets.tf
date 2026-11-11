# The existing database credentials are stored centrally and injected at task startup.
# Terraform still stores secret values in state; protect state and saved plans.
resource "aws_secretsmanager_secret" "db" {
  name_prefix             = "${local.name}-db-"
  description             = "Database credentials for the DVWA training lab"
  recovery_window_in_days = 7
  tags                    = { Stage = "layer4" }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_user
    password = var.db_password
  })
}

# Same-account resource policy grants only the existing ECS execution role access.
# It cannot override an explicit lab deny. No new IAM roles/policies are created.
resource "aws_secretsmanager_secret_policy" "db" {
  secret_arn          = aws_secretsmanager_secret.db.arn
  block_public_policy = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowLabExecutionRoleRead"
      Effect    = "Allow"
      Principal = { AWS = data.aws_iam_role.lab.arn }
      Action    = ["secretsmanager:GetSecretValue"]
      Resource  = aws_secretsmanager_secret.db.arn
    }]
  })
}

output "db_secret_arn" {
  value       = aws_secretsmanager_secret.db.arn
  description = "Secret reference only; never output the secret value."
}
