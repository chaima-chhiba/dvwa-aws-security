variable "db_user" {
  type        = string
  default     = "dvwa"
  description = "Database user. Still hardcoded at this stage; layer 4 moves it to Secrets Manager."
}

variable "db_password" {
  type        = string
  default     = "Password123"
  description = "Still a plaintext weak password at layer 1 on purpose (fixed by layer 4)."
}

variable "desired_count" {
  type        = number
  default     = 1
  description = "Keep at 1 so the session cookie used by attacks.sh stays valid. Use 0 to stop the app without destroying."
}
