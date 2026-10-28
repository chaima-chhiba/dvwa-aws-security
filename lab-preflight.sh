#!/usr/bin/env bash
# lab-preflight.sh - checks which services/actions the AWS Learner Lab allows.
# Every check is read-only or creates-then-deletes a tiny free object.
# Usage: bash lab-preflight.sh [region]      (default region: us-east-1)
# Output is also saved to evidence/00-baseline/lab-preflight.txt
set -uo pipefail

REGION="${1:-us-east-1}"
export AWS_DEFAULT_REGION="$REGION"
OUT="$(dirname "$0")/evidence/00-baseline/lab-preflight.txt"
mkdir -p "$(dirname "$OUT")"
: > "$OUT"

log() { printf '%s\n' "$*" | tee -a "$OUT"; }
pass() { log "[ALLOWED] $1"; }
fail() { log "[BLOCKED] $1  ->  $2"; }

# run <label> <command...>   : passes if exit code 0
run() {
  local label="$1"; shift
  local msg
  if msg="$("$@" 2>&1)"; then pass "$label"; else fail "$label" "$(printf '%s' "$msg" | head -1 | cut -c1-140)"; fi
}

log "Lab preflight - $(date -u +%FT%TZ) - region $REGION"
log "-----------------------------------------------"

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  log "AWS credentials not working. In Learner Lab: Start Lab -> AWS Details -> Show -> copy the"
  log "credentials into ~/.aws/credentials (including aws_session_token), then re-run."
  exit 1
fi
log "Identity: $(aws sts get-caller-identity --query Arn --output text)"
log

log "== Core services (list calls) =="
run "ECS list clusters"            aws ecs list-clusters
run "ECR describe repositories"    aws ecr describe-repositories
run "RDS describe instances"       aws rds describe-db-instances
run "ELBv2 describe load balancers" aws elbv2 describe-load-balancers
run "EC2 describe VPCs"            aws ec2 describe-vpcs
run "Secrets Manager list"         aws secretsmanager list-secrets
run "CloudWatch describe alarms"   aws cloudwatch describe-alarms
run "SNS list topics"              aws sns list-topics
run "CloudTrail describe trails"   aws cloudtrail describe-trails
run "WAFv2 list web ACLs (regional)"    aws wafv2 list-web-acls --scope REGIONAL
run "WAFv2 list web ACLs (CLOUDFRONT, us-east-1)" aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1
run "CloudFront list distributions" aws cloudfront list-distributions
run "ACM list certificates (expected blocked)" aws acm list-certificates
log

log "== IAM roles =="
run "IAM get LabRole"              aws iam get-role --role-name LabRole
run "IAM list server certificates" aws iam list-server-certificates
log

log "== Write test: IAM server certificate upload (fallback for HTTPS on the ALB) =="
tmp="$(mktemp -d)"
if command -v openssl >/dev/null 2>&1; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 7 -subj "/CN=dvwa-lab.local" \
    -keyout "$tmp/key.pem" -out "$tmp/cert.pem" >/dev/null 2>&1
  name="preflight-test-$RANDOM"
  if msg="$(aws iam upload-server-certificate --server-certificate-name "$name" \
        --certificate-body "file://$tmp/cert.pem" --private-key "file://$tmp/key.pem" 2>&1)"; then
    pass "IAM upload-server-certificate"
    aws iam delete-server-certificate --server-certificate-name "$name" >/dev/null 2>&1 \
      && log "          (test certificate deleted)"
  else
    fail "IAM upload-server-certificate" "$(printf '%s' "$msg" | head -1 | cut -c1-140)"
  fi
else
  log "[SKIPPED] openssl not installed"
fi
rm -rf "$tmp"
log

log "== Default VPC / quotas hints =="
run "EC2 describe availability zones" aws ec2 describe-availability-zones
run "EC2 describe NAT gateways"       aws ec2 describe-nat-gateways
log

log "-----------------------------------------------"
log "How to read this:"
log " - ACM BLOCKED is expected (that is why we use CloudFront's default certificate)."
log " - CloudFront ALLOWED + WAF CLOUDFRONT ALLOWED  -> Option A works (recommended)."
log " - CloudFront BLOCKED but IAM upload ALLOWED     -> Option B (HTTPS listener on the ALB)."
log " - Both blocked                                  -> Option C (nginx TLS in the container)."
log " - ECS BLOCKED                                   -> fall back to EC2 + Docker for both stages."
log
log "Saved to $OUT"
