# 📊 Business Plan Annexes - Complete Document

> **Document V17 - Updated: January 08, 2026**
> Detailed annexes with strategic and financial analyses
> **Legal Status: Auto-Entrepreneur (Sole Proprietorship)**

---

## TABLE OF CONTENTS

1. [Full Pricing Plans](#a-full-pricing-plans)
2. [Pure SEPA Architecture](#b-pure-sepa-architecture)
3. [Harmonized T&Cs](#c-harmonized-t&cs)
4. [Market Study](#d-market-study)
5. [PESTEL Analysis](#e-pestel-analysis)
6. [SWOT Analysis](#f-swot-analysis)
7. [Competitive Analysis](#g-competitive-analysis)
8. [Costs & Charges](#h-costs-&-charges)
9. [Marketing Plan](#i-marketing-plan)
10. [Financial Projections](#j-financial-projections)
11. [Personas](#k-personas)
12. [Team & Structure](#l-team-&-structure)
13. [Roadmap](#m-product-roadmap)
14. [Fundraising](#n-fundraising)

---

## A. Full Pricing Plans

### A.1 Individual Plans

| Plan | Price €/month | Price FCFA/month | Tontines | Participants | Max Contribution |
|------|-------------|----------------|----------|--------------|----------------|
| **Free** | 0 | 0 | 1 | 5 | 500€ |
| **Starter** | 3.99 | 2,500 | 2 | 10 | 500€ |
| **Standard** | 6.99 | 4,500 | 3 | 15 | 500€ |
| **Premium** | 9.99 | 6,500 | 5 | 20 | 500€ |

> 💬 *Comment: Prices are aligned with standard SaaS freemium models. The Free plan serves as an acquisition tool, while Starter is a psychologically accessible paid entry point (<5€).*

### A.2 Corporate Plans (Tontetic Corporate)

| Plan | Employees | Tontines | Price €/month | Support | Max Contribution |
|------|----------|----------|-------------|---------|----------------|
| **Starter** | 12 | 1 | 19.99 | Flexible | 200€ |
| **Starter Pro** | 24 | 2 | 29.99 | Flexible | 200€ |
| **Team** | 48 | 4 | 39.99 | Flexible | 200€ |
| **Team Pro** | 60 | 4 | 49.99 | Priority | 200€ |
| **Department** | 84 | 7 | 69.99 | Priority | 200€ |
| **Enterprise** | 108 | 10 | 89.99 | Dedicated | 200€ |
| **Unlimited** | ∞ | ∞ | Upon quote | Premium 24/7 | Upon quote |

> 💬 *Comment: Multiples of 12 (typical team sizes). Prices are based on the B2B SaaS market (20-100€/month for HR/well-being tools).*

### A.3 Merchant System

| Type | Required KYC | Revenue Limit | Max Offers | Price/month |
|------|------------|-----------|------------|-----------|
| **Individual** | Email + PSP ID | 3,000€/year | 5 | 4.99€ |
| **Verified** | Tax ID + ID + Selfie | Unlimited | Unlimited | 9.99€ |

> 💬 *Comment: The 3,000€/year ceiling for Individuals corresponds to the simplified micro-BNC threshold. Beyond that = mandatory Tax ID (SIRET).*

### A.4 Merchant Boost Options (Source code)

| Option | Price € | Duration | Availability |
|--------|--------|-------|---------------|
| 1-day Boost | 1.99€ | 1 day | All |
| 7-day Boost | 9.99€ | 7 days | All |
| Homepage Feature | 29.99€ | 30 days | Verified only |

> 💬 *Comment: Prices are based on social media ad standards (1-10€/day). The Homepage boost is premium as it is highly visible.*

### A.5 "Pioneers" Launch Offer

| Parameter | Value |
|-----------|--------|
| Eligible Creators | First 20 |
| Offered Duration | 3 months FREE Starter |
| Invitations per Creator | 9 people max |
| Maximum Reach | **200 users** |
| After 3 months | Auto-switch to chosen plan |

> 💬 *Comment: 20×10 = 200 qualified users via word-of-mouth. Opportunity cost: 200×3×3.99€ = ~2,400€ in deferred revenue.*

---

## B. Pure SEPA Architecture

### B.1 Fundamental Principle

> **Tontetic NEVER touches user funds**

| Element | V17 Architecture |
|---------|-----------------|
| Fund Transit | Direct member → beneficiary (via PSP) |
| Processing Fees | ❌ REMOVED |
| Insurance | ❌ NOT OFFERED |
| Internal Wallet | ❌ REMOVED |
| ACPR/EMI License | ❌ Not required |

### B.2 Double SEPA Mandate

| Mandate | Type | Trigger |
|--------|------|---------------|
| A - Contributions | Recurring debit | Automatic monthly |
| B - Guarantee | Conditional authorization | After 3 failures + 7 days |

> 💬 *Comment: This architecture avoids any reclassification as a payment institution. PSD2 compliance is ensured via authorized PSPs.*

---

## C. Harmonized T&Cs

### C.1 Structure

| Section | Articles | Content |
|---------|----------|---------|
| General | 1-10 | Tontines, Contributions, Guarantees, Blocking |
| Users | 1-20 | Account Creation, Vote, Responsibilities |
| Corporate | 1-17 | B2B Plans, Limits, Dashboard |
| Merchants | 1-20 | LCEN Art.6, Boost, No sale |

### C.2 Regulatory Compliance

| Regulation | Status | Justification |
|----------------|--------|---------------|
| EMI License | Not required | No fund holding |
| GDPR | ✅ Compliant | `gdpr_service.dart` |
| LCEN Art.6 | ✅ Host | Content moderation |
| PSD2 | ✅ Via PSP | Licensed Stripe/Wave |

---

## D. Market Study

### D.1 TAM / SAM / SOM

| Level | Population | Estimation | Source |
|--------|------------|------------|--------|
| **TAM** (Total Addressable Market) | Banked population in Africa + Diaspora | ~150M people | World Bank 2023 [TO BE VERIFIED] |
| **SAM** (Serviceable Available Market) | Smartphone + data + tontine practice | ~30M people | GSMA Estimation [TO BE VERIFIED] |
| **SOM** (Serviceable Obtainable Market) | Realistic 1st year adoption | ~50K users | Internal estimation |

> 💬 *Comment: TAM based on banked population in UEMOA (~40%) + European diaspora (~3M). SAM = 20% who actively practice tontines.*

### D.2 Tontine Market

| Region | Population | % Tontine Practitioners | Potential Market |
|--------|------------|------------------------|------------------|
| **Senegal** | 17M | ~40% [TO BE VERIFIED] | ~7M people |
| **Ivory Coast** | 27M | ~35% [TO BE VERIFIED] | ~9M people |
| **Mali** | 21M | ~30% [TO BE VERIFIED] | ~6M people |
| **Cameroon** | 27M | ~45% [TO BE VERIFIED] | ~12M people |
| **French Diaspora** | ~1.5M | ~60% [TO BE VERIFIED] | ~900K people |

> 💬 *Comment: Percentages are estimated based on ILO studies and field surveys. Diaspora = higher rate due to maintaining traditions.*

### D.3 Market Trends

| Trend | Impact | Opportunity |
|----------|--------|-------------|
| Africa Digitalization | ↗️ Strong | Mobile money adoption +30%/year |
| Fintech Regulation | ↔️ Medium | Pure SEPA = no license required |
| Connected Diaspora | ↗️ Strong | Remittances: $45Bn/year to Africa |
| Low Competition | ↗️ Strong | No major tontine app identified |

---

## E. PESTEL Analysis

### E.1 Political Factors

| Factor | Impact | Analysis |
|---------|--------|---------|
| West Africa Stability | ↔️ Medium | Risks in Mali/Burkina, stable in Senegal/Ivory Coast |
| France-Africa Relations| ↔️ Medium | Tensions exist but diaspora remains connected |
| UEMOA Fintech Policy | ↗️ Positive | Encouragement of innovation (BCEAO) |
| French ACPR Regulation | ↔️ Neutral | Pure SEPA = exempt |

### E.2 Economic Factors

| Factor | Impact | Analysis |
|---------|--------|---------|
| Euro Zone Inflation | ↘️ Negative | ~2-3% in 2025, stable purchasing power |
| Africa GDP Growth | ↗️ Positive | Avg. +4-6%/year (IMF) |
| EUR/FCFA Exchange Rate| ↔️ Stable | Fixed parity: 1€ = 655.957 FCFA |
| Africa Banking Rate | ↗️ Positive | ~45% in UEMOA, increasing [TO BE VERIFIED] |

### E.3 Sociocultural Factors

| Factor | Impact | Analysis |
|---------|--------|---------|
| Tontine Tradition | ↗️ Very Positive | Ancestral practice = established trust |
| Gen Z Digitalization | ↗️ Positive | 70% of 18-35 year olds on smartphones |
| Community Solidarity | ↗️ Positive | Core value in West Africa |
| Banking Mistrust | ↗️ Positive | Tontines = historic alternative |

### E.4 Technological Factors

| Factor | Impact | Analysis |
|---------|--------|---------|
| Smartphone Penetration | ↗️ Positive | ~55% sub-Saharan Africa (GSMA 2024) |
| 4G/5G Coverage | ↔️ Medium | 4G: 70% in urban areas, limited in rural |
| Mobile Money (Wave) | ↗️ Very Positive | +40%/year, existing PSP infrastructure |
| Generative AI | ↗️ Positive | Tontii = unique UX differentiator |

### E.5 Environmental Factors

| Factor | Impact | Analysis |
|---------|--------|---------|
| Circular Economy | ↗️ Positive | Tontines = local solidarity savings |
| Digital Carbon Impact | ↔️ Neutral | Cloud servers (AWS/GCP = carbon neutrality) |

### E.6 Legal Factors

| Factor | Impact | Analysis |
|---------|--------|---------|
| European GDPR | ↔️ Neutral | Compliance implemented (export/deletion) |
| PSP Regulation | ↗️ Positive | Via Stripe/Wave = licensed |
| PSD2 | ↗️ Positive | Open Banking = opportunity |
| AML-CFT (Anti-money laundering) | ↔️ Medium | 500€/200€ thresholds + KYC = compliance |

---

## F. SWOT Analysis

### F.1 Strengths

| Strength | Detail |
|-------|--------|
| **Pure SEPA Architecture** | No license required, simplified compliance |
| **Dual EUR/FCFA Currency** | Diaspora + Native Africa market |
| **Automatic Guarantee** | 1 contribution, objective and transparent triggering |
| **Democratic Vote (Borda)** | Equity in pot order, UX innovation |
| **Tontii AI** | Unique UX differentiator in the market |
| **Honor Score** | Quantified community trust |
| **7 Corporate Plans** | Full B2B flexibility |
| **Merchant Space** | Diversified complementary revenue |

### F.2 Weaknesses

| Weakness | Detail |
|-----------|--------|
| **No Traction** | MVP under development, 0 real users |
| **Small Team** | Solo founder in Y1 |
| **Limited Marketing Budget**| ~500€ max in Y1 (sole proprietorship) |
| **PSP Dependency** | Stripe/Wave could change conditions |
| **No Physical Presence** | 100% remote operations |

### F.3 Opportunities

| Opportunity | Detail |
|-------------|--------|
| **Non-digitalized Market** | 95%+ tontines still informal (WhatsApp/paper) |
| **Large Diaspora** | ~1.5M Senegalese in France, high practice rate |
| **Growing Mobile Money** | Wave, Orange Money = ready local PSPs |
| **No Direct Competitor** | No major tontine app identified |
| **Underexploited B2B** | Corporate tontines = untapped niche |

### F.4 Threats

| Threat | Detail |
|--------|--------|
| **Future Regulation** | Risk of PSP reclassification by ACPR |
| **Banks/Fintechs Entry** | Orange, Wave, Revolut could copy |
| **Massive Fraud** | Reputation risk if chain defaults occur |
| **Political Instability** | Sahel country risk (Mali, Burkina) |

---

## G. Competitive Analysis

### G.1 Direct Competitors

| Criterion | Tontetic | Direct Competitor |
|---------|----------|------------------|
| **Name** | Tontetic | None identified to date |
| **Region** | FR + FCFA | - |
| **Dual Currency** | ✅ | - |
| **Auto Guarantee** | ✅ | - |
| **Integrated AI** | ✅ | - |
| **B2B** | ✅ | - |

> 💬 *Comment: Competitive research to be deepened. No major direct competitor identified in the "digital tontine + guarantee + B2B" niche.*

### G.2 Indirect Competitors

| Type | Examples | Weakness vs Tontetic |
|------|----------|----------------------|
| **WhatsApp Groups** | Informal tontines | No security, no traceability |
| **Excel/Notebooks** | Manual management | Errors, no guarantee |
| **Traditional Banks** | Savings products | Not culturally adapted |
| **Mobile Money** | Wave, Orange | No integrated tontine management |

---

## H. Costs & Charges

### H.1 Monthly Fixed Costs (Auto-Entrepreneur Y1)

| Item | Description | Cost/month | Cost/year | Status |
|-------|-------------|-----------|---------|--------|
| **Supabase** | PostgreSQL DB (Free→Pro) | 0€→25€ | **~150€** | Estimated |
| **Firebase** | Auth + Push (Spark) | 0€ | **0€** | Free |
| **Gemini API**| Tontii AI (pay-per-use) | ~15€ | **~180€** | [TO BE VERIFIED] |
| **Domain** | tontetic.io (.io = premium) | ~2€ | **~25€** | Estimated |
| **Google Workspace**| Pro Email (Starter) | 6€ | **72€** | Fixed |
| **Cloudflare**| CDN + SSL (Free) | 0€ | **0€** | Free |
| **Apple App Store**| Developer License | - | **99€** | Fixed |
| **Google Play Store**| One-time fee | - | **25€** | One-time |
| **TECH SUB-TOTAL** | | | **~550€** | |

> 💬 *Comment: Stack optimized for minimal costs. Supabase free tier is sufficient up to ~10K users. Firebase Spark is free up to 10K auth/month.*

### H.2 Admin Fixed Costs (Auto-Entrepreneur Y1)

| Item | Description | Cost/year | Status |
|-------|-------------|---------|--------|
| **AE Creation** | Free (URSSAF online) | **0€** | Fixed |
| **CFE** | Business Property Tax | **0€** (exempt Y1) | Fixed |
| **Accounting**| DIY (revenue log) | **0€** | - |
| **Bank Account**| Dedicated account (Shine free) | **0€** | Optional |
| **RC Pro Insurance**| Optional Y1 | **0€** | Optional |
| **ADMIN SUB-TOTAL** | | **~0€** | |

> 💬 *Comment: Auto-entrepreneurs benefit from Y1 exemptions. No complex accounting obligations. RC Pro is recommended but not mandatory for digital activity.*

### H.3 Variable Costs Y1

| Item | Calculation Basis | Y1 Estimation | Status |
|-------|----------------|---------------|--------|
| **Stripe fees** | 1.4% + 0.25€/tx | **~280€** | Estimated |
| | On ~15,000€ revenue, ~300 tx| | |
| **Wave fees** | ~1.5%/tx [TO BE VERIFIED] | **~75€** | [TO BE VERIFIED] |
| | On ~5,000€ revenue FCFA | | |
| **SMS OTP** | 0.04€/SMS × 5,000 users | **~200€** | Estimated |
| **Transac Emails**| SendGrid Free (100/day) | **0€** | Free |
| **VARIABLE SUB-TOTAL** | | **~555€**| |

### H.4 Auto-Entrepreneur Social Charges

| Item | Rate | Estimated Revenue Base | Y1 Amount |
|-------|------|-----------------|------------|
| **URSSAF Contributions** | 21.2% (BNC) | ~20,000€ | **~4,240€** |
| **CFP (Voc. Training)**| 0.2% | ~20,000€ | **~40€** |
| **TOTAL SOCIAL CHARGES** | | | **~4,280€** |

> 💬 *Comment: 2025 BNC rate = 21.2% for service provisions. CFP = contribution to professional training.*

### H.5 Y1 Costs Summary (Solo Auto-Entrepreneur)

| Category | Amount | Notes |
|-----------|---------|-------|
| **Tech Infrastructure** | ~550€ | Optimized free tiers |
| **Admin/Legal** | ~0€ | AE Exemptions |
| **Variable Costs** | ~555€ | PSP + SMS |
| **Social Charges** | ~4,280€ | 21.2% of Revenue |
| **Marketing** | ~500€ | Minimal budget |
| **TOTAL Y1 COSTS** | **~5,885€**| |

### H.6 Y1 Taxes (Auto-Entrepreneur)

| Option | Calculation | Amount |
|--------|--------|---------|
| **Flat-rate Withholding** | 2.2% × Revenue | ~440€ |
| **OR Income Tax (IR)** | 34% deduction + bracket | Variable |

---

## I. Marketing Plan

### I.1 Y1 Marketing Budget (Minimal)

| Item | Y1 Budget | Strategy |
|-------|-----------|-----------|
| **Facebook/Instagram Ads** | ~300€ | Targeted diaspora tests |
| **Organic TikTok** | 0€ | DIY viral content |
| **Canva Pro** | ~120€ | Visual creation |
| **Partnerships** | 0€ | Visibility exchange with associations |
| **TOTAL Y1 MARKETING** | **~420€** | Bootstrap budget |

### I.2 Acquisition Strategy

| Canal | Target | Estimated CAC | Expected LTV | Ratio |
|-------|-------|------------|-------------|-------|
| **Organic Referral** | FR Diaspora | ~0€ | ~50€ | ∞ |
| **Viral WhatsApp** | Existing groups | ~0€ | ~60€ | ∞ |
| **Facebook Ads** | 25-45 yo diaspora | ~8€ [TO BE VERIFIED] | ~50€ | 6:1 |
| **Organic TikTok** | 18-35 yo | ~0€ | ~40€ | ∞ |

---

## J. Financial Projections

### J.1 Basic Assumptions

| Variable | Y1 | Y2 | Y3 |
|----------|----|----|-----|
| Total Users | 5,000 | 25,000 | 100,000 |
| % Free | 70% | 60% | 50% |
| % Starter (3.99€) | 15% | 20% | 25% |
| % Standard (6.99€) | 10% | 12% | 15% |
| % Premium (9.99€) | 5% | 8% | 10% |
| **Average ARPU** | ~2.50€ | ~3.50€ | ~4.50€ |

### J.2 Projected Revenue

| Source | Y1 | Y2 | Y3 |
|--------|----|----|-----|
| **Individual Subscriptions** | **15,000€** | 105,000€ | 540,000€ |
| **Corporate Subscriptions** | **3,600€** | 36,000€ | 180,000€ |
| **Merchant Subscriptions** | **600€** | 6,000€ | 30,000€ |
| **Merchant Boost** | **500€** | 5,000€ | 25,000€ |
| **TOTAL REVENUE** | **~19,700€** | **~152,000€** | **~775,000€** |

### J.3 Y1 Income Statement (Auto-Entrepreneur)

| Line | Amount | Notes |
|-------|---------|-------|
| **Revenue (CA)** | ~20,000€ | AE Ceiling = 77,700€ |
| (-) Variable Costs | -555€ | PSP + SMS |
| **Gross Margin** | **~19,445€** | 97% |
| (-) Tech Fixed Costs | -550€ | Cloud infra |
| (-) Marketing | -420€ | Minimal budget |
| (-) Social Charges | -4,280€ | 21.2% URSSAF |
| (-) Tax (2.2% Wh.) | -440€ | Optional |
| **Net Result** | **~13,755€**| Y1 Profit |

---

## K. Personas

### K.1 Aminata - French Diaspora

| Attribute | Value |
|----------|--------|
| Age | 32 years old |
| Location | Paris 18th |
| Profession | Nurse |
| Goal | Secure her family tontine |
| **Probable Plan** | Starter (3.99€) |

### K.2 Moussa - Urban Africa

| Attribute | Value |
|----------|--------|
| Age | 28 years old |
| Location | Dakar |
| Profession | Car Salesman |
| Goal | Create his own circles |
| **Probable Plan**| Standard (4,500 FCFA) |

---

## L. Team & Structure

### L.1 Y1 Team (Solo Founder)

| Position | Name | Status |
|-------|-----|--------|
| **CEO / CTO / Founder** | [TO BE COMPLETED] | Auto-Entrepreneur |

### L.2 Legal Structure

| Element | Value |
|---------|--------|
| **Statut** | Auto-Entrepreneur (Sole Proprietorship) |
| **Activity** | Application software publishing |

---

## M. Product Roadmap

### M.1 Q1 2026 (Done)
- MVP Core, Dual Currency, SEPA Guarantee, Tontii AI, Merchant Space, Corporate Plans.

### M.2 Q2 2026
- App Store, Play Store, Production launch (Stripe/Wave).

---

## N. Fundraising

### N.1 Y1 Strategy (Bootstrap)
- Goal: Prove traction before raising. Milestone: 5,000 active users.

### N.2 Future Round (Y2)
- **Pre-seed**: 50-100K€ TARGET.

---

## O. KPIs to Track
- MAU target Y1: 3,000.
- Conversion target: 30%.
- Churn target: <5%.

---

## P. Glossary
- **ARPU**: Average Revenue Per User.
- **CAC**: Customer Acquisition Cost.
- **LTV**: Lifetime Value.
- **PSP**: Payment Service Provider.

---

*Document V17 - Generated on: January 08, 2026*
*Status: Auto-Entrepreneur Y1*
