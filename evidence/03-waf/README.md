# Layer 3 evidence checklist

- [ ] Reviewed plan: only web ACL and ALB association additions.
- [ ] Successful apply summary.
- [ ] Regional web ACL rules, priorities, and managed rule actions.
- [ ] Existing ALB listed as the associated resource.
- [ ] Benign HTTPS request returns the expected login page status.
- [ ] CloudWatch WAF metrics and sanitized sampled requests, when available.
- [ ] Any measured filtering result, with matching evidence; do not infer blocking from configuration alone.

Terraform prepared locally; no Layer 3 AWS deployment or filtering result verified yet.
Do not save cookies, credentials, private keys, raw state, or sensitive request details.
