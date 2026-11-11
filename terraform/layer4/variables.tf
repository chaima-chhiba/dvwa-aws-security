variable "db_user" {
  type        = string
  default     = "dvwa"
  description = "Database user. Still hardcoded at this stage; layer 4 moves it to Secrets Manager."
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Existing database password, supplied privately. Layer 4 changes delivery, not the database password."
}

variable "desired_count" {
  type        = number
  default     = 1
  description = "Keep at 1 so the session cookie used by attacks.sh stays valid. Use 0 to stop the app without destroying."
}
