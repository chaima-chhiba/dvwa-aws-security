# Layer 2 evidence checklist

## Captured on 2026-11-11
- `01-certificate-tagging-denied.png`: partial apply failed on iam:TagServerCertificate; HTTP listener modification completed before failure.
- `02-plan-summary.png`: intermediate plan, 2 additions, 1 change, no destruction.
- `03-ecs-tag-only-diff.png`: intermediate ECS change contains only Stage tag changes. This is not proof of a successful deployment.

## Still needed
- Final reviewed plan after preserving the ECS service tag.
- Successful Terraform apply summary.
- HTTP response showing 301 and an HTTPS Location header.
- HTTPS response for /login.php and TLS connection details (self-signed certificate).
- ALB console showing HTTP redirect and HTTPS listener, certificate, and TLS policy.
- IAM certificate details (never the private key).
- Optional client-side capture demonstrating TLS application traffic; it does not prove encryption between ALB and app.

Keep credentials, cookies, private keys, and Terraform state out of evidence.

- Reviewed plan captured: 04-reviewed-plan.png. Only IAM certificate and HTTPS listener additions; 2 add, 0 change, 0 destroy. Apply success still pending.

- Successful apply captured: 05-apply-complete.png (2 added, 0 changed, 0 destroyed). Connectivity validation remains pending.

- Connectivity confirmed: HTTP 301 to HTTPS and HTTPS 200 with curl -k. See 08-connectivity-observed.txt and sanitized response files. Screenshot containing session cookies was not copied. TLS details and console screenshots remain pending.

- TLS handshake captured: 10-tls-handshake.png and 09-tls-details.txt. TLS 1.3 negotiated; expected self-signed verification warning. Remaining: ALB listener configuration and certificate metadata screenshots.

- ALB console captured: 11-alb-overview.png and 12-alb-listeners.png. Redirect and HTTPS forwarding confirmed. Still needed: HTTPS listener details showing full security policy and certificate metadata.

- Certificate attachment and metadata captured: 13-https-listener-details.png and 14-iam-certificate.png. IAM imported certificate expires December 11, 2026, 22:04 UTC+01:00. Remaining console capture: HTTPS listener Security tab with full TLS policy.

## Current completion status
Required console screenshots and connectivity checks are captured. 15-tls-security-policy.png confirms ELBSecurityPolicy-TLS13-1-2-2021-06 (mTLS off). Earlier pending checklist entries above are historical and now satisfied, except the optional packet capture, which has not been collected. Self-signed trust and HTTP backend limitations remain.
