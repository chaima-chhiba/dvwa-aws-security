variable "db_user" {
  type        = string
  default     = "dvwa"
  description = "Database user (weak on purpose, baseline only)"
}

variable "db_password" {
  type        = string
  default     = "Password123"
  description = "Weak database password, hardcoded on purpose for the baseline. Layer 4 moves it to Secrets Manager."
  # RDS forbids / @ \" and spaces in passwords.
}

variable "desired_count" {
  type        = number
  default     = 1
  description = "Keep at 1 so the session cookie used by attacks.sh stays valid. Use 0 to stop the app without destroying."
}
