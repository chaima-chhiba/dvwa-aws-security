- Learner Lab preflight (2026-10-28): ECS, ECR, RDS, ALB, Secrets Manager, CloudWatch, SNS, CloudTrail, NAT, WAF (regional + CloudFront scope) allowed. CloudFront blocked, ACM unavailable. IAM server certificate upload allowed.
- Decision: HTTPS via self-signed certificate uploaded to IAM, attached to an ALB HTTPS listener (replaces ACM). WAF attached directly to the ALB.
- Evidence: evidence/00-baseline/lab-preflight.txt

## 2026-10-28 - Baseline deployment
- terraform apply succeeded (15 resources). Baseline destroyed at end of session.
- Open issue: browser to task public IP gave ERR_CONNECTION_RESET. To check: curl from WSL, ECS service events, container logs (/ecs/dvwa-baseline), ECR image present.
