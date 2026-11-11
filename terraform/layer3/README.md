# Layer 3: regional WAF

This full configuration adds an AWS WAFv2 regional web ACL and its ALB association.
The AWS managed common and SQL injection rule groups retain their normal actions.
Metrics and request sampling are enabled. Full WAF log delivery is deferred to Layer 5.
Managed rules mitigate selected requests; they do not repair DVWA or guarantee every
malicious request is blocked. Benign traffic must also be checked for false positives.

## One deployment, one state file

The local backend explicitly reuses `../layer2/terraform.tfstate`. Never copy the state
into Layer 3 or run the stage directories concurrently. After Layer 3 is applied,
use Layer 3 for all plans, applies, and teardown; applying Layer 2 would remove WAF.
Only the default Terraform workspace is supported by this lab workflow.
Do not delete the Layer 2 state file while this deployment exists.

Existing provider tags remain at Layer 2 (and the ECS service keeps Layer 1) to avoid
unnecessary resource updates under restricted lab permissions. The WAF is tagged Layer 3.
The certificate provider still omits tags because iam:TagServerCertificate is denied.

From the repository root, in WSL Bash:

```bash
test -s terraform/layer2/terraform.tfstate
terraform -chdir=terraform/layer3 init -lockfile=readonly
terraform -chdir=terraform/layer3 workspace show
terraform -chdir=terraform/layer3 validate
terraform -chdir=terraform/layer3 plan -no-color
```

Stop if the workspace is not `default`, the state file is missing, or the plan
proposes anything beyond the WAF web ACL and association. Expected: 2 additions,
0 changes, 0 destruction, plus output changes. Review the real plan before applying.
Never share saved plans or state: they contain database credentials and the TLS key.

## Evidence

Save sanitized plan/apply summaries, WAF rules, ALB association, metrics, and a benign
HTTPS availability check in `evidence/03-waf/`. Exclude cookies and sensitive sampled
request data. Record observed filtering results only when independently demonstrated;
configuration and zero blocked requests alone do not demonstrate blocking efficacy.

## Session end

When finished with the deployment, use `terraform -chdir=terraform/layer3 destroy`,
review the teardown plan, verify completion, then End Lab. Never destroy Layer 2
separately: Layer 3 uses the same state and includes the whole deployment.
