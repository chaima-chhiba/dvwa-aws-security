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

- Reviewed plan captured in 01-reviewed-plan.png: expected web ACL and ALB association only, 2 additions, 0 changes, 0 destruction. Deployment remains pending.

- Apply completion captured: 02-apply-complete.png, 2 added, 0 changed, 0 destroyed. Association readback and benign availability check pending; no measured blocking result yet.

- Association and benign availability verified in 05-association-and-availability.png: expected web ACL attached; HTTPS status 200. Remaining: managed rule configuration, metrics/sanitized samples, and any independently measured filtering results.

- Console overview captured in 06-waf-console-overview.png (web ACL and two-rule count). Detail views for rules and associated ALB still needed.

- 07-managed-rule-groups.png confirms both expected groups and order. Numeric priorities/actions still need readback.
- 08-console-resource-permission-limits.png documents lab console list-permission limitations. Use 03-alb-waf-association.json and 05-association-and-availability.png for verified association, rather than inferring from the restricted console view.

- 10-rule-configuration-readback.png confirms default Allow, priorities 10/20, and OverrideAction None for both AWS managed groups. Configuration verification complete; metrics and measured blocking results remain pending.

- 11-dashboard-insights-overview.png captures recommendation insights only, with zero category counts; request metrics and sampled rows are not visible. Do not interpret this as blocking evidence or proof of no traffic.

- 12-request-metrics.png: selected three-hour window totals 9 requests, 9 allowed, 0 blocked. Metrics evidence captured. Sampled request rows and measured blocking results remain outstanding.

- 13-sampled-allowed-requests.png captures populated sampling with ALLOW rows. Sampled-request evidence is now collected; blocking effectiveness is still unmeasured. Source IPs are visible; anonymize them before including this screenshot in a publicly shared report.
