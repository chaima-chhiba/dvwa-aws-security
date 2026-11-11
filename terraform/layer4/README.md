# Layer 4: Secrets Manager

Preserves network isolation, HTTPS, and WAF. Moves DB_USER and DB_PASSWORD out of
the task definition environment list into ECS secrets references to JSON keys.
Fargate Linux platform 1.4.0 supports JSON-key injection. Secret retrieval uses
the existing LabRole execution role. A secret resource policy grants that role
GetSecretValue without creating or changing IAM roles. Explicit lab denies still
apply, and permission to create the secret policy must be verified during apply.
The default Secrets Manager encryption key is used.

## State and credentials

Uses the SAME `terraform/layer2/terraform.tfstate` via a local backend. Do not copy
state or run earlier stages concurrently. After deployment, manage and destroy
through Layer 4 only. Default Terraform workspace only.

Supply the EXISTING database password privately via TF_VAR_db_password; no default
password is committed in this layer. Use the same db_user and other variable values
as the active deployment. This layer does not rotate the database password.
Never paste the password or raw state into chat. Saved plans and state contain
secret values and the TLS private key. Historical task definitions/state backups
may still contain old plaintext credentials; this change does not erase history.

ECS injects secrets as runtime environment variables. They can still be read from
inside the container by sufficiently privileged code. Rotation is not configured;
updated secret values require a new task deployment.

## Deployment review (WSL Bash, repository root)

```bash
test -s terraform/layer2/terraform.tfstate
terraform -chdir=terraform/layer4 init -lockfile=readonly
terraform -chdir=terraform/layer4 validate
read -r -s -p 'Existing DB password: ' TF_VAR_db_password
printf '\n'
export TF_VAR_db_password
terraform -chdir=terraform/layer4 plan -replace=aws_ecs_service.dvwa -no-color
```

Review before applying. Expected: three Secrets Manager resources, a new task
definition revision replacing the old definition resource, and deliberate ECS
service replacement because ecs:UpdateService is denied. Expected totals are
5 additions, 0 in-place changes, 2 destructions; real output must be checked.
Stop for VPC, RDS, ALB, or WAF changes. Service replacement temporarily interrupts
availability; do not add create_before_destroy with the same ECS service name.
The service depends on both the secret version and resource policy before launch.

Only after plan review, apply with the SAME replacement option. If secret policy
creation fails or tasks cannot retrieve secrets, collect the exact error and ECS
service/stopped-task events. Do not broaden permissions speculatively.

## Evidence and teardown

Capture sanitized plan/apply summaries, secret metadata (not Retrieve secret value),
task-definition credential names and references, service health, and an application
database-dependent success check. A login page 200 alone does not prove DB access.
Where DescribeTaskDefinition is denied, inspect local state with a script that emits
only names/references and boolean checks, never the raw container definitions.

Destroy via `terraform -chdir=terraform/layer4 destroy` using the same private input.
Secrets are scheduled for deletion with a 7-day recovery window; the unique name
prefix avoids recreation conflicts. Confirm teardown, unset TF_VAR_db_password,
then End Lab. Do not delete the shared state before successful teardown.
