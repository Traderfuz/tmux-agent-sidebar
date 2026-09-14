<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/live-client-action-gate.md and re-run profile-sync. -->
# Live Client Action Gate

## Overview

Any agent or automated process operating in the Boxi platform has direct access to real client contact data, signing platforms, messaging APIs, and payment systems. Without an explicit gate, an agent exploring or testing a feature can irreversibly send communications, trigger legal signing requests, or charge clients — all without the operator ever intending it. This standard defines a hard confirmation gate that MUST fire before any outbound action reaches a real client contact.

## Scope

This standard covers agent-initiated and automated outbound actions that target real client contact data (email addresses, phone numbers, signing submissions, payment records). It does NOT cover read-only API calls, internal data queries, dashboard navigation, or admin-only operations that have no external-facing effect.

## Principles

1. **Real clients are never test subjects.** All feature testing, verification, and QA MUST use designated internal test accounts. Real client data is never an acceptable substitute for a test fixture.
2. **Irreversibility demands confirmation.** Any action that cannot be trivially undone (sending an email, triggering a signature request, sending an invoice) requires explicit human confirmation before execution — regardless of how confident the agent is.
3. **Describe before you act.** Before requesting confirmation, the agent MUST state exactly what it will send, to whom, via which channel, and what the recipient will experience. Vague confirmation requests ("should I proceed?") are not sufficient.
4. **Silence is not consent.** A confirmation gate is not satisfied by the absence of a "stop" command. It requires an affirmative "yes proceed" signal.
5. **Test accounts are the default.** When building, verifying, or demonstrating any send flow, reach for the internal test account first. Using a real client account for convenience is a violation even when no send occurs.

## Rules

### R1 — Confirmation gate before any outbound action (`MUST`)

Any agent action that invokes one of the following MUST pause and present a confirmation prompt before executing:

- DocuSeal: `createSubmission()`, `POST /api/webhooks/docuseal`, "Send for Signature" UI action
- Email: `sendLeadEmailAction()`, `sendCampaignEmails()`, `processEmailCampaigns()`, Resend API calls with real recipient addresses
- SMS: `sendSmsAction()`, `sendSmsCampaign()`, Twilio API calls targeting real phone numbers
- Invoices: `sendInvoiceAction()`, any Paddle charge or subscription trigger
- Proposals: "Send for Signature", "Mark as Sent" when targeting a real client contact
- EmailCampaigns: any sequence import, broadcast scheduling, subscriber/lead targeting, campaign send, or cron drain targeting non-test recipients
- Webhooks: any outbound webhook that POSTs to an external URL with real client payload

**Confirmation prompt format (MUST include all four fields):**

```
⚠ OUTBOUND ACTION — requires confirmation before executing

  Action:    Send for Signature (DocuSeal submission)
  Recipient: Marcus Johnson <marcus@carolinacomforthvac.com>
  Channel:   DocuSeal signing link via email
  Effect:    Client receives signing request; cannot be recalled once sent

Type "yes proceed" to continue, or anything else to abort.
```

### R2 — Use test accounts for all agent testing (`MUST`)

When an agent needs to exercise a send flow for verification, testing, or demonstration:

- **Email:** use `test@boximarketing.com` or `admin@boximarketing.com`
- **Proposals/DocuSeal:** use the seeded test proposal (proposalId prefixed `demo-fixture-*`) and a test submitter email
- **SMS:** use the internal Twilio test number (`+15005550006` in test mode) or `OWNER_PHONE_NUMBERS`
- **Invoices:** use Paddle sandbox mode — never Paddle production with real payment methods
- **EmailCampaigns:** use test campaigns scoped to `@boximarketing.com` recipients only

Real client records MUST NOT be used for testing even if no send is executed — browsing a real client's proposal detail page to "check the UI" is acceptable; clicking any send-path button on a real client record is not.

### R3 — Confirmation gate applies regardless of context (`MUST`)

The gate fires in ALL contexts:
- Agent-automated flows (autonomous, implement-tasks, deliver-product-slice)
- Browser-CDP sessions driven by the AI
- Manual QA verification steps
- Production deploy verification
- Debugging live issues

The only exemption: actions targeting addresses that match `*@boximarketing.com` or phone numbers in `OWNER_PHONE_NUMBERS`.

### R4 — Violation classification (`MUST NOT`)

Sending any outbound action to a real client without the confirmation gate having fired and received explicit approval is a **P0 incident**. It MUST be:
1. Logged immediately in `product/inbox.jsonl` as a P0 capture
2. Reported to the operator within the same session
3. Followed by a post-incident note describing what was sent, to whom, and what remediation was taken (e.g., apology email, revoked signing link)

## Anti-patterns

| Anti-pattern | Why it fails | Correct alternative |
|---|---|---|
| Clicking "Send for Signature" on a real client proposal during a QA verification pass | Sends irreversible signing request to real client | Use a `demo-fixture-*` proposal with `test@boximarketing.com` as the submitter |
| Using a real lead's email in `sendLeadEmailAction()` to verify the send path works | Sends real email to a real person | Use `test@boximarketing.com` as the `to` address |
| Asking "should I proceed?" without describing the action | Operator cannot give informed consent | State action, recipient, channel, and effect before requesting confirmation |
| Running `process-email-campaigns` cron in production to "see if it works" | Sends real campaign emails to real subscribers | Run with a test campaign scoped to `@boximarketing.com` subscribers only |
| Assuming "it's just a draft" prevents a send | Draft proposals still have "Send for Signature" button accessible | Gate fires on the button click, not on draft status |

## Deviation guidance

You MAY skip the confirmation gate when:
- The recipient address matches `*@boximarketing.com`
- The phone number is in `OWNER_PHONE_NUMBERS`
- The action is targeting Paddle sandbox (not production) payment environment
- The action is a Twilio test-mode call (`+15005550006`)

You MUST NOT skip the gate for any other reason, including:
- "This is just a quick verification"
- "The client is expecting this"
- "It was already sent once before"
- "The operator didn't say stop"

## Test accounts reference

| Channel | Test target | Notes |
|---|---|---|
| Email | `test@boximarketing.com`, `admin@boximarketing.com` | Always available |
| Proposals | `demo-fixture-*` prefixed records | Created by `scripts/seed-demo-fixtures.ts` |
| SMS | `OWNER_PHONE_NUMBERS` env var | Routes to owner cell, not a client |
| DocuSeal | `test@boximarketing.com` as submitter email | Creates real submission but to internal address |
| Invoices | Paddle sandbox environment | Requires `PADDLE_SANDBOX=true` |
| EmailCampaigns | Test campaign scoped to `@boximarketing.com` recipients only | Do not target production lead/subscriber filters |

## Compliance test

- [ ] Before any DocuSeal `createSubmission()` call targeting a non-internal email, did the agent display the full four-field confirmation prompt and receive "yes proceed"?
- [ ] Is the recipient address for all test/verification sends `*@boximarketing.com` or `OWNER_PHONE_NUMBERS`?
- [ ] Does the confirmation prompt include: action name, recipient identity, delivery channel, and irreversibility warning?
- [ ] Is any outbound action that fired without confirmation logged as a P0 capture in `product/inbox.jsonl`?
- [ ] Are all demo/test proposals identified by a `demo-fixture-*` ID prefix and use `test@boximarketing.com` as the contact?

If any check fails: **abort the action immediately**, log a P0 capture if a send already occurred, and report to the operator before continuing.

## References

- [GDPR Article 5 — Purpose Limitation](https://gdpr-info.eu/art-5-gdpr/) — data collected for one purpose (client management) must not be used for another (agent testing) without a lawful basis
- [SOC 2 Least Privilege Principle](https://www.aicpa.org/resources/article/soc-2-frequently-asked-questions) — automated systems should operate with the minimum necessary permissions and actions
- [12-Factor App — Dev/Prod Parity](https://12factor.net/dev-prod-parity) — environments should be as similar as possible, but test data must never cross into production client records
- [NIST SP 800-53 AC-6 — Least Privilege](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final) — automated processes must not be granted or exercise capabilities beyond what is required for legitimate operation
