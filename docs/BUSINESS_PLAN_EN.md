# 📊 Business Plan - Tontetic

> **Document V17 - Updated: January 07, 2026**
> Pure SEPA Architecture + Merchant System + Harmonized T&Cs

---

## 1. Executive Summary

### 1.1 Vision
**Tontetic** digitalizes traditional African and European tontines, providing security, transparency, and accessibility via a modern mobile application.

### 1.2 Value Proposition

| Problem | Tontetic Solution |
|----------|-------------------|
| Informal tontines = default risk | SEPA conditional guarantee (1 contribution) |
| Trust between members | Democratic voting (Borda) + Honor Score |
| Paper/Excel management | Mobile App + Admin Dashboard |
| Lack of traceability | Immutable logs + Legal Export |
| Lack of assistance | Tontii AI + Multi-level Support |
| No marketplace | Integrated Merchant Space |

### 1.3 Key Figures

| Metric | Value |
|----------|--------|
| Individual Plans | 4 (Free → Premium) |
| Corporate Plans | 7 (Starter → Unlimited) |
| Max Individual Price | 6.99€/month |
| Max Corporate Price | Upon quote |
| Target Markets | Euro Zone + FCFA Zone |
| Model | Freemium + Subscriptions + Merchant Boost |

---

## 2. Technical Architecture (V17)

### 2.1 Pure SEPA - Fundamental Principle

> **Tontetic NEVER touches user funds**

| Element | V17 Architecture |
|---------|-----------------|
| Fund Transit | Direct member → beneficiary (via PSP) |
| Processing Fees | ❌ **REMOVED** |
| Insurance | ❌ **NOT OFFERED** |
| Internal Wallet | ❌ **REMOVED** |
| ACPR/EMI License | ❌ **Not required** |
| Legal Status | Technical service provider (LCEN Art.6) |

### 2.2 Double SEPA Mandate

| Mandate | Type | Trigger |
|--------|------|---------------|
| **A - Contributions** | Recurring debit | Automatic monthly |
| **B - Guarantee** | Conditional authorization | After 3 failures + 7 days |

### 2.3 Implemented Security

| Feature | Status | File |
|----------------|--------|---------|
| Device Fingerprinting | ✅ | `device_fingerprint_service.dart` |
| Persistent Logs | ✅ | `persistent_audit_service.dart` |
| GDPR (Art. 15, 17, 20) | ✅ | `gdpr_service.dart` |
| Anonymous AI Logging | ✅ | `ai_conversation_logging_service.dart` |
| KYC | ✅ | `kyc_service.dart` |

---

## 3. Economic Model

### 3.1 Revenue Sources

| Source | Description | % Revenue |
|--------|-------------|-----------|
| **Individual Subscriptions** | Starter/Standard/Premium Plans | ~60% |
| **Corporate Subscriptions** | B2B Plans | ~25% |
| **Merchant Boost** | Product visibility | ~10% |
| **Merchant Subscriptions** | Merchant Space Access (One-off) | ~5% |

### 3.2 Individual Plans

| Plan | Price €/month | Price FCFA/month | Tontines | Participants |
|------|-------------|----------------|----------|--------------|
| **Free** | 0 | 0 | 1 | 5 |
| **Starter** | 2.99 | 2,000 | 2 | 10 |
| **Standard** | 4.99 | 3,500 | 3 | 15 |
| **Premium** | 6.99 | 4,500 | 5 | 20 |

**Max Contribution: 500€**

### 3.3 Corporate Plans (Tontetic Corporate)

| Plan | Employees | Tontines | Price €/month |
|------|----------|----------|-------------|
| **Starter** | 12 | 1 | 19.99 |
| **Starter Pro** | 24 | 2 | 29.99 |
| **Team** | 48 | 4 | 39.99 |
| **Team Pro** | 60 | 4 | 49.99 |
| **Department** | 84 | 7 | 69.99 |
| **Enterprise** | 108 | 10 | 89.99 |
| **Unlimited** | ∞ | ∞ | Upon quote |

**Max Corporate Contribution: 200€**

### 3.4 Merchant System (V17)

| Merchant Type | KYC | Revenue Limit | Offers | Price/month |
|---------------|-----|-----------|--------|-----------|
| **Individual** | Light (email + PSP ID) | 3,000€/year | 5 max | 14.99€ (One-off) |
| **Verified** | Full (Tax ID + ID) | Unlimited | Unlimited | 14.99€ (One-off) |

**Boost Revenue:**
| Option | Price | Duration |
|--------|------|-------|
| Simple Boost | 500 FCFA | 1 day |
| Premium Boost | 2,000 FCFA | 7 days |
| Homepage Feature | 5,000 FCFA | 24h |

> ⚠️ **Crucial**: No commission on sales. No in-app payments.

### 3.5 "Pioneers" Launch Offer

| Parameter | Value |
|-----------|--------|
| Eligible Creators | First 20 |
| Offered Duration | 3 months FREE Starter |
| Invitations per Creator | 9 people max |
| Maximum Reach | **200 users** |
| After 3 months | Auto-switch to chosen plan |

---

## 4. Legal Framework (Harmonized T&Cs V17)

### 4.1 T&C Structure

| Section | Articles | Main Content |
|---------|----------|-------------------|
| **General** | 1-10 | Tontines, Contributions, Guarantees, Voluntary Blocking |
| **Users** | 1-20 | Account Creation, Vote/Random, Responsibilities |
| **Corporate** | 1-17 | B2B Plans, 200€ Limits, Dashboard |
| **Merchants** | 1-20 | LCEN Art.6, No sale, Boost |

### 4.2 Key Legal Principles

| Principle | Implementation |
|----------|----------------|
| Technical Provider (LCEN) | ✅ T&Cs + UI disclaimers |
| Not a Payment Institution | ✅ Pure SEPA Architecture |
| No Holding of Funds | ✅ Direct PSP Transit |
| Prohibition of Internal Wallet | ✅ UI "PSP Synthesis" |
| Guarantee = Authorization | ✅ `sepa_guarantee_service.dart` |
| AI = Not Financial Advice | ✅ `gemini_service.dart` |

### 4.3 Regulatory Compliance

| Regulation | Compliance | Justification |
|----------------|------------|---------------|
| **EMI License** | Not required | No fund holding |
| **GDPR** | ✅ Compliant | Export/deletion/anonymization |
| **LCEN Art.6** | ✅ Host | Content moderation |
| **PSD2** | ✅ Via PSP | Licensed Stripe/Wave |
| **AML-CFT** | ✅ Partially | Thresholds + KYC |

---

## 5. Product Features (23 Modules)

```
lib/features/
├── admin/          # Admin back-office
├── advertising/    # Advertising/boosts + Merchant Space
├── ai/             # Tontii AI (Gemini)
├── auth/           # Authentication
├── chat/           # Circle messaging
├── corporate/      # Corporate B2B (7 plans)
├── dashboard/      # Dashboard
├── kyc/            # Identity verification
├── legal/          # Harmonized T&Cs
├── merchant/       # Merchant Space (Individual/Verified)
├── onboarding/     # Startup tutorial
├── payments/       # Pure SEPA + Guarantees
├── referral/       # Referral program
├── savings/        # Voluntary Fund Blocking
├── security/       # Fingerprinting + Logs
├── settings/       # Preferences + GDPR
├── shop/           # Marketplace
├── social/         # Social sharing
├── subscription/   # Subscriptions (Individuals + Corporate)
├── tontine/        # Core business logic
└── wallet/         # PSP Synthesis (not internal wallet)
```

---

## 6. Financial Projections

### 6.1 Assumptions

| Variable | Y1 | Y2 | Y3 |
|----------|----|----|----| 
| Active Users | 5,000 | 25,000 | 100,000 |
| % Paying | 30% | 40% | 50% |
| Average ARPU | 2.50€ | 3.50€ | 4.50€ |
| B2B Corporate Clients | 10 | 50 | 200 |

### 6.2 Projected Revenue

| Source | Y1 | Y2 | Y3 |
|--------|----|----|----| 
| **Individual Subscriptions** | 15,000€ | 105,000€ | 540,000€ |
| **Corporate Subscriptions** | 3,600€ | 36,000€ | 180,000€ |
| **Merchant Boost** | 1,000€ | 15,000€ | 75,000€ |
| **Total** | **19,600€** | **156,000€** | **795,000€** |

---

## 7. Go-to-Market

| Phase | Duration | Objective |
|-------|-------|----------|
| **MVP** | Month 1-3 | 500 beta-testers (diaspora) |
| **Soft Launch** | Month 4-6 | 5,000 users (France) |
| **FCFA Expansion** | Month 7-12 | Senegal, Ivory Coast |
| **Scale** | Y2+ | 100K users |

---

## 8. Risks & Mitigation

| Risk | Probability | Impact | Mitigation |
|--------|-------------|--------|------------|
| Fraud/Massive Defaults | Medium | High | 1 contribution guarantee + KYC |
| PSP Blocking | Low | Very High | Multi-PSP (Stripe+Wave+Orange) |
| Competition | Medium | Medium | AI+UX+Merchant differentiation |
| FCFA Regulation | Low | High | Local EMI partnership |
| PSP Requalification | Low | Very High | Strict Pure SEPA architecture |

---

## 9. KPIs to Track

| KPI | Definition | Y1 Target |
|-----|------------|----------|
| **MAU** | Monthly Active Users | 5,000 |
| **Conversion** | Free → Paid | 30% |
| **Churn** | Monthly Subscriber Loss | <5% |
| **ARPU** | Average Revenue Per User | 2.50€ |
| **NPS** | Recommendation Score | >50 |
| **B2B Companies** | Active Accounts | 10 |
| **Active Merchants** | Individual + Verified | 50 |

---

## 10. Team & Structure

| Role | Responsibilities |
|------|-----------------|
| **CEO** | Strategy, Fundraising, Partnerships |
| **CTO** | Pure SEPA Architecture, Security, DevOps |
| **CPO** | UX/UI, Product Roadmap, Beta testing |
| **Legal** | T&Cs, Compliance, GDPR |
| **Growth** | Marketing, Community, Referrals |

---

## Appendices

- [BUSINESS_PLAN_ANNEXES_EN.md](./BUSINESS_PLAN_ANNEXES_EN.md) - Detailed matrices
- [Full T&Cs](../lib/core/constants/legal_texts.dart) - Articles 1-10 + Merchants 1-20

---

*Document V17 - Generated on: January 07, 2026*
*Based on: Tontetic Source Code Analysis + T&C Audit*
