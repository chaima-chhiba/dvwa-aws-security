#!/usr/bin/env bash
# push-image.sh - copies the DVWA image into our ECR repository.
# Run from the repo root, after the ECR repo exists (terraform apply -target=aws_ecr_repository.dvwa).
# Usage: bash scripts/push-image.sh [source-image]
set -euo pipefail

SRC="${1:-ghcr.io/digininja/dvwa:latest}"   # upstream DVWA; reads DB_* environment variables
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
REPO="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com/dvwa"

echo "[..] Pulling $SRC"
docker pull "$SRC"

echo "[..] Logging in to ECR"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"

docker tag "$SRC" "$REPO:latest"
echo "[..] Pushing $REPO:latest"
docker push "$REPO:latest"
echo "[OK] Image pushed. Now run: cd terraform/baseline && terraform apply"
