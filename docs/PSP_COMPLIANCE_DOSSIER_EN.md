# 📋 PSP Compliance Dossier - Tontetic

## 1. Platform Overview

### 1.1 Identity
- **Company Name**: Tontetic SAS
- **Activity**: Digital tontine management platform
- **Regulatory Status**: Technical Host (LCEN Art.6)
- **Compliance Contact**: compliance@tontetic.io

### 1.2 Economic Model

```
┌─────────────────────────────────────────────────────────────────┐
│                     FINANCIAL ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│      USER ────────► PSP (Stripe/Wave) ────────► BENEFICIARY      │
│        │                     │                                   │
│        │                     │                                   │
│        ▼                     ▼                                   │
│   ┌─────────┐         ┌───────────┐                             │
│   │ TONTETIC│◄────────│ WEBHOOKS  │                             │
│   │ (Read   │         │ (Reading) │                             │
│   │ Only)   │         └───────────┘                             │
│   └─────────┘                                                    │
│                                                                  │
│   ⚠️ TONTETIC NEVER HOLDS THE FUNDS                             │
│   ⚠️ TONTETIC CANNOT INITIATE TRANSFERS                         │
│   ⚠️ ALL OPERATIONS ARE PSP → PSP                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 Reasons for Non-EMI Licensing Requirement

| Criterion | Status | Justification |
|-----------|--------|---------------|
| Fund Holding | ❌ No | Funds are on PSP accounts |
| Currency Issuance | ❌ No | No tokens/points |
| Payment Execution | ❌ No | PSP executes everything |
| Account Management | ❌ No | Accounts = PSP accounts |
| Funds Transfers | ❌ No | PSP → PSP only |

---

## 2. Integrated PSPs

### 2.1 Stripe (Euro Zone)
- **License**: EMI (E-Money Institution)
- **Regulator**: Central Bank of Ireland
- **Services Used**:
  - Stripe Connect (merchant accounts)
  - Stripe Payment Intents
  - Signed Webhooks

### 2.2 Wave (FCFA Zone)
- **License**: EMI (E-Money Institution)
- **Regulator**: BCEAO (Central Bank of West African States)
- **Services Used**:
  - Wave Business API
  - Signed Webhooks

---

## 3. Security Architecture

### 3.1 The 6 Pillars

| Pillar | Description | Implementation |
|--------|-------------|----------------|
| **Authentication** | Strong passwords + 2FA | Supabase Auth + Biometrics |
| **Authorization** | Granular RBAC | AdminPermissionService |
| **Financial Security** | Idempotence + validation | FinancialSecurityPillar |
| **API Protection** | Rate limiting | RateLimitService |
| **Auditability** | Immutable logs | PersistentAuditService |
| **Incident Response** | Documented procedures | RUNBOOK.md |

### 3.2 Data Flux

```
┌──────────────────────────────────────────────────────────────┐
│                        PAYMENT FLOW                          │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  1. User initiates contribution in the app                   │
│                      │                                        │
│                      ▼                                        │
│  2. App redirects to PSP checkout (Stripe/Wave)              │
│                      │                                        │
│                      ▼                                        │
│  3. User pays directly to the PSP                            │
│                      │                                        │
│                      ▼                                        │
│  4. PSP notifies Tontetic via signed webhook                 │
│                      │                                        │
│                      ▼                                        │
│  5. Tontetic validates signature + updates the display       │
│                      │                                        │
│                      ▼                                        │
│  6. At the end of the cycle, PSP pays the beneficiary        │
│     (ordered by Tontetic, executed by PSP)                   │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. GDPR Compliance

### 4.1 Collected Data

| Data | Purpose | Legal Basis | Duration |
|------|---------|-------------|----------|
| Email | Identification | Contract | Active account + 5 years |
| Phone | Authentication | Contract | Active account + 5 years |
| Name | Identification | Contract | Active account + 5 years |
| Transactions | Tontine execution | Contract | 5 years (AML-CFT) |
| SEPA Mandates | Direct debits | Contract | 10 years |
| Logs | Security/Audit | Legitimate interest | 5 years |

### 4.2 User Rights

| Right | Implementation | Delay |
|-------|----------------|-------|
| Access (Art.15) | GDPRService.exportUserData() | 30 days |
| Rectification (Art.16) | User profile | Immediate |
| Deletion (Art.17) | GDPRService.requestDeletion() | 30 days |
| Portability (Art.20) | JSON Export | 30 days |

### 4.3 DPO
- **Contact**: dpo@tontetic.io
- **CNIL Declaration**: [Number to be completed]

---

## 5. Anti-Money Laundering (AML-CFT)

### 5.1 Implemented Measures

| Measure | Description |
|---------|-------------|
| **Thresholds** | 500€/month (325,000 FCFA) per user |
| **KYC** | Email + Phone verification |
| **Monitoring** | Abnormal behavior detection |
| **Reporting** | TRACFIN reporting procedure |

### 5.2 Reporting Obligations

- TRACFIN: Via documented procedure
- Asset Freezing: Verification of EU sanctions list

---

## 6. Technical Documentation

### 6.1 Webhooks

| Endpoint | Signature | Retry |
|----------|-----------|-------|
| /webhooks/stripe | HMAC-SHA256 | 3x with backoff |
| /webhooks/wave | HMAC-SHA256 | 3x with backoff |

### 6.2 Audit Logs

- **Format**: JSON with hash chain
- **Storage**: Supabase (EU)
- **Retention**: 5 years
- **Export**: Available upon request

---

## 7. Tests and Audits

### 7.1 Security Tests

| Type | Frequency | Last |
|------|-----------|------|
| Unit tests | CI/CD | Every commit |
| Integration tests | Weekly | 2026-01-06 |
| External Pentest | Annual | To be scheduled |

### 7.2 Certifications

| Certification | Status | Scheduled Date |
|---------------|--------|----------------|
| ISO 27001 | 📋 Planned | 2026 Q4 |
| PCI-DSS | ✅ Delegated | Via Stripe |
| SOC 2 | 📋 Planned | 2027 Q1 |

---

## 8. Contacts

| Role | Contact |
|------|---------|
| **Compliance** | compliance@tontetic.io |
| **DPO** | dpo@tontetic.io |
| **Legal** | legal@tontetic.io |
| **Technical** | tech@tontetic.io |
| **Support** | support@tontetic.io |

---

## 9. Attachments

- [ ] Current T&Cs (dated version)
- [ ] Privacy Policy
- [ ] PSP Contracts (non-confidential excerpts)
- [ ] Architecture Diagram
- [ ] GDPR Compliance Report
- [ ] TRACFIN Procedure

---

*Document prepared on: 2026-01-06*
*Version: 1.0*
*Next revision: 2026-04-06*
