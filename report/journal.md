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

- User-provided Layer 3 plan confirms only aws_wafv2_web_acl.dvwa and aws_wafv2_web_acl_association.alb will be created: 2 add, 0 change, 0 destroy. Evidence: evidence/03-waf/01-reviewed-plan.png. Apply and filtering validation pending.

- Layer 3 apply succeeded per user screenshot: 2 added, 0 changed, 0 destroyed. Saved evidence/03-waf/02-apply-complete.png. WAF association readback, benign HTTPS availability, and rule evidence remain pending; filtering effectiveness is not yet demonstrated.

- User output confirms get-web-acl-for-resource returns dvwa-layer1-waf for the existing ALB, and benign HTTPS /login.php returns 200. Saved evidence/03-waf/05-association-and-availability.png; command outputs saved as 03-alb-waf-association.json and 04-benign-https-check.txt. Managed rule configuration and measured filtering evidence still pending.

- Saved evidence/03-waf/06-waf-console-overview.png: WAF console lists dvwa-layer1-waf with two rules. Rule names/actions and associated resource detail screenshots remain pending.

- Saved 07-managed-rule-groups.png: AWSManagedRulesCommonRuleSet precedes AWSManagedRulesSQLiRuleSet; console shows 700 and 200 WCU respectively. Numeric priorities and override actions are not visible in this screenshot.
- Saved 08-console-resource-permission-limits.png: console denies apprunner:ListAssociatedServicesForWebAcl and wafv2:ListResourcesForWebACL. ALB is displayed, but association proof remains the successful earlier get-web-acl-for-resource readback. No IAM changes needed for this evidence workaround.

- WAF API readback verified in user screenshot: default Allow; AWSManagedRulesCommonRuleSet priority 10 and AWSManagedRulesSQLiRuleSet priority 20; each has OverrideAction None and AWS vendor. Saved evidence/03-waf/10-rule-configuration-readback.png; JSON captured as 09-rule-configuration.json. Deployment, association, benign HTTPS availability, and intended rule configuration verified. Metrics and measured blocking effectiveness remain unverified.

- Saved evidence/03-waf/11-dashboard-insights-overview.png. Dashboard shows zeros in traffic-insight recommendation categories and Last 3 hours selected; request metrics and sampled-request rows are below the visible area. These zeros do not demonstrate zero requests or successful blocking. Request metrics and filtering measurement remain pending.

- WAF dashboard user screenshot shows Last 3 hours: Total 9, Allowed 9, Blocked 0, CAPTCHA 0, Challenged 0, Monetized 0. Saved evidence/03-waf/12-request-metrics.png. Confirms dashboard request metrics are populated; does not establish request origins, absence of false positives generally, or blocking effectiveness. Sampled request rows are not visible.

- Sampled requests subsequently became visible in user screenshot. Saved evidence/03-waf/13-sampled-allowed-requests.png. Visible rows use dvwa-web-acl metric, show ALLOW for paths including /, /sse, /login.php, /favicon.ico, and /mcp; no rule inside a rule group is listed for those rows. Request origins are not attributed. This supersedes the earlier user-reported empty sampling view; no blocking result has been observed.

## 2026-11-11 - Layer 4 preparation
- Layer 3 evidence committed/pushed as c56bf5e after explicit approval to include screenshots with source IPs in the private repository.
- Created layer4 branch. Prepared secret/version/resource policy restricted to existing LabRole, JSON-key ECS secret injection, platform 1.4.0, and shared local state.
- Removed password default in Layer 4 and marked private password input sensitive. Existing database password must be supplied unchanged; no rotation intended.
- Local initialization and Terraform validation passed. AWS plan, permissions, replacement deployment, and runtime retrieval remain unverified. ECS service replacement will interrupt availability; secrets/state/runtime environment limitations documented in terraform/layer4/README.md.

- User Layer 4 plan shows 5 add, 1 change, 2 destroy. ECS service/task definition replacements and Secrets Manager additions expected; aws_db_instance.dvwa in-place update is unexpected. Apply paused pending sanitized DB diff review. Evidence: evidence/04-secrets/01-plan-unexpected-db-update.png. Password mismatch is a possibility, not a confirmed diagnosis.

- Sanitized DB diff identifies password as the sole visible changed attribute. Saved evidence/04-secrets/02-db-password-diff.png. User instructed to reuse the existing state-managed password locally without printing it, then re-plan. No apply performed; no database rotation intended.

- Revised user plan after locally reusing the state-managed DB password: 5 add, 0 change, 2 destroy. Only ECS service/requested replacement, task definition replacement, and secret/policy/version additions listed; database update resolved. Saved evidence/04-secrets/03-reviewed-plan.png. Apply and runtime retrieval remain pending.

- User screenshot confirms Layer 4 apply complete: 5 added, 0 changed, 2 destroyed. Saved evidence/04-secrets/04-apply-complete.png. Service health, runtime secret retrieval, sanitized task-definition references, and database-dependent application check remain pending.

- ECS service readback shows ACTIVE, desired/running 1, pending 0, Failures empty, task definition revision 2. Events confirm deployment completed and steady state. Saved evidence/04-secrets/06-service-steady-state.png and user command output 05-service-health.json. Credential-reference inspection and database-dependent functional check remain pending.

- Sanitized local-state check passed for task definition revision 2: no DB_USER/DB_PASSWORD plaintext environment entries; both exact expected Secrets Manager JSON-key references present. Saved evidence/04-secrets/08-secret-reference-check.png; JSON saved as 07-secret-reference-check.json. Revision matches earlier ECS service API readback. This is local-state evidence, not DescribeTaskDefinition API proof. Database-dependent login check remains pending.

- User screenshot shows DVWA home at HTTPS /index.php after certificate-warning guidance. Saved evidence/04-secrets/09-dvwa-home-https.png. Browser flags untrusted self-signed certificate as expected. Screenshot alone does not establish a fresh database-backed login versus an existing session; fresh login confirmation remains pending.

- User clarified that 09-dvwa-home-https.png was captured immediately after logging in, not merely reopening an existing session. Fresh application login succeeded after Layer 4 deployment (user-confirmed functional check). Combined with revision 2 running and sanitized secret-reference check, this supports successful secret-backed database authentication. Remaining evidence: secret metadata/resource policy and explicit target-health readback; plaintext history/state/runtime-environment limitations still apply.

- Saved 10-secrets-manager-list.png and 11-secret-metadata.png: secret exists in us-east-1; name/ARN match configured references; encryption key aws/secretsmanager shown; secret value not retrieved in screenshot. List shows last retrieved November 11, 2026, without identifying the caller. Remaining evidence: resource policy readback and explicit target-health check.

- Secret resource policy readback confirms Allow for arn role/LabRole, action secretsmanager:GetSecretValue, scoped to the database secret ARN. Saved evidence/04-secrets/13-resource-policy-readback.png; JSON captured as 12-secret-resource-policy.json. This is a scoped grant, not proof that only LabRole can access the secret or that LabRole has least privilege overall. Explicit ALB target-health evidence remains pending.

- Final Layer 4 target-group screenshot: one total target, one healthy, zero unhealthy/initial/draining. Saved evidence/04-secrets/14-target-healthy.png. Backend protocol HTTP:80 remains visible and documented as a TLS limitation. Layer 4 evidence collected: apply, ECS steady state/revision 2, sanitized credential reference check, user-confirmed fresh login, secret metadata, scoped resource policy, target health. This does not erase historical plaintext task revisions/state or remove credentials from runtime environment.
