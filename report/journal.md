- Learner Lab preflight (2026-10-28): ECS, ECR, RDS, ALB, Secrets Manager, CloudWatch, SNS, CloudTrail, NAT, WAF (regional + CloudFront scope) allowed. CloudFront blocked, ACM unavailable. IAM server certificate upload allowed.
- Decision: HTTPS via self-signed certificate uploaded to IAM, attached to an ALB HTTPS listener (replaces ACM). WAF attached directly to the ALB.
- Evidence: evidence/00-baseline/lab-preflight.txt

## 2026-10-28 - Baseline deployment
- terraform apply succeeded (15 resources). Baseline destroyed at end of session.
- Open issue: browser to task public IP gave ERR_CONNECTION_RESET. To check: curl from WSL, ECS service events, container logs (/ecs/dvwa-baseline), ECR image present.

## 2026-11-02 - Baseline evidence
- attacks.sh on baseline: SQLi (5 users dumped), reflected XSS, direct DB access from internet (3306), plaintext DB_PASSWORD in task definition: all succeeded.
- Evidence: evidence/00-baseline/

## 2026-11-11 - Layer 2 HTTPS troubleshooting
- Saved three user-provided screenshots in evidence/02-https; deployment is not yet verified.
- Certificate upload failed because provider default tags required denied iam:TagServerCertificate. Added an untagged certificate provider.
- Remaining ECS plan change was Stage tags only. Preserved the service's layer1 tag to avoid an unnecessary service update.
- Evidence checklist: evidence/02-https/README.md. Next: validate and review the new plan before applying.

- User-provided revised plan confirms only aws_iam_server_certificate.alb and aws_lb_listener.https will be created: 2 add, 0 change, 0 destroy. Saved evidence/02-https/04-reviewed-plan.png. Deployment success pending.

- Layer 2 apply succeeded (user screenshot): 2 added, 0 changed, 0 destroyed. IAM certificate and HTTPS listener created. Evidence: evidence/02-https/05-apply-complete.png. HTTP redirect and HTTPS response validation pending.

- User evidence confirms HTTP 301 redirect to HTTPS and HTTPS HTTP/2 200 on /login.php using curl -k. Saved sanitized observation in evidence/02-https/08-connectivity-observed.txt; removed Set-Cookie headers from response files. Certificate verification and TLS details remain to be checked.

- TLS handshake confirmed by user output: TLSv1.3, TLS_AES_128_GCM_SHA256, X25519 ephemeral key exchange. Expected self-signed certificate verification error observed. Evidence: evidence/02-https/09-tls-details.txt and 10-tls-handshake.png. This establishes client-to-ALB TLS only; backend remains HTTP and public certificate trust is not established.

- Saved AWS console screenshots: 11-alb-overview.png (active internet-facing ALB) and 12-alb-listeners.png (HTTP:80 redirect to HTTPS:443 with HTTP_301; HTTPS:443 forwards to dvwa-layer1-tg). Full TLS policy and certificate name are truncated in the listener table; detailed evidence remains pending.

- Saved 13-https-listener-details.png and 14-iam-certificate.png. Console confirms imported IAM certificate attached as default to HTTPS:443, forwarding to the app target group. Certificate expires December 11, 2026 at 22:04 (UTC+01:00); expiry warning is consistent with the 30-day lab certificate. Full TLS security policy screenshot still pending.

- Final console evidence saved: evidence/02-https/15-tls-security-policy.png confirms ELBSecurityPolicy-TLS13-1-2-2021-06; mTLS is off. Layer 2 deployment, HTTP redirect, HTTPS response, negotiated TLS 1.3, IAM certificate attachment, and listener policy are documented. Optional packet capture remains uncollected. Limitations: self-signed certificate requires explicit trust; ALB-to-app remains HTTP; application vulnerabilities remain. No claim of end-to-end encryption.

## 2026-11-11 - Layer 3 preparation
- Layer 2 committed and pushed as 5487b4c on layer2; created layer3 branch.
- Added regional WAF managed common and SQL injection rule groups, metrics, sampling, and ALB association. Full log delivery remains for Layer 5.
- Layer 3 explicitly reuses terraform/layer2/terraform.tfstate via a local backend; no state copy. After Layer 3 apply, use Layer 3 for management and teardown. Deployment and filtering results remain unverified.
- Layer 3 initialization and terraform validate passed with pinned providers; workspace is default. AWS plan and deployment pending.
