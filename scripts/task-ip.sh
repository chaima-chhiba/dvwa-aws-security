#!/usr/bin/env bash
# task-ip.sh - prints the public IP / URL of the running DVWA task.
# The IP changes every time the task restarts, so rerun this after any restart.
set -euo pipefail

CLUSTER="${1:-dvwa-baseline-cluster}"
SERVICE="${2:-dvwa-baseline-svc}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

TASK_ARN="$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" --desired-status RUNNING \
  --query 'taskArns[0]' --output text --region "$REGION")"

if [[ -z "$TASK_ARN" || "$TASK_ARN" == "None" ]]; then
  echo "[WARN] No running task yet. Check progress with:"
  echo "  aws ecs describe-services --cluster $CLUSTER --services $SERVICE --query 'services[0].events[:5].message' --region $REGION"
  exit 1
fi

ENI="$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" --region "$REGION" \
  --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value | [0]" --output text)"

IP="$(aws ec2 describe-network-interfaces --network-interface-ids "$ENI" --region "$REGION" \
  --query 'NetworkInterfaces[0].Association.PublicIp' --output text)"

echo "Task:  $TASK_ARN"
echo "IP:    $IP"
echo "URL:   http://$IP/"
echo "Setup: http://$IP/setup.php"
