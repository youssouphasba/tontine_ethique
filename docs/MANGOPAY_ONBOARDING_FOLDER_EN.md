# Onboarding Dossier: Ethical Tontine (Tontetic)

**Version**: 1.1 — February 2026
**Subject**: Request for accreditation as a Payment Service Provider Agent (PISP/AISP agent).

---

## 1. Project Vision
Ethical Tontine (Tontetic) digitalizes the ancestral practice of the tontine (rotating savings). It caters to communities seeking solidarity-based savings without bank interest, by providing transparency, security, and a reputation score ("Honor Score").

## 2. Financial Flow Architecture (Non-Custodial Model)
The system relies on a strict separation of funds via the Mangopay infrastructure:

### A. Wallet Structure
- **User Wallet**: Each member possesses an identified wallet.
- **Circle Wallet (Escrow)**: Optional, for consolidation before redistribution.
- **Fees Wallet**: For collecting subscriptions and service fees by Tontetic.

### B. Tontine Cycle (Example)
1.  **Join**: Signing of a circle contract (Charter) and a Mangopay SEPA mandate.
2.  **Contribution**: Automatic debit (PayIn SEPA Direct Debit) from the member's bank account to their Mangopay Wallet.
3.  **Consolidation**: Transfer (Wallet → Wallet) of member contributions towards the designated beneficiary's Wallet for the cycle.
4.  **Payout**: Transfer (Wallet → Verified IBAN) to the beneficiary.

> [!NOTE]
> Ethical Tontine never has access to the funds. It acts solely as a technical orchestrator via API.

---

## 3. Compliance & AML-CFT Framework
The fight against money laundering and terrorist financing is at the heart of our architecture.

### A. KYC / KYB (Know Your Customer)
User onboarding follows three levels of verification:
- **Level 1 (Light)**: Email, Phone (OTP), Name, First Name.
- **Level 2 (Standard)**: Identity document verification (Passport/ID Card) synchronized with Mangopay.
- **Level 3 (Verified)**: Liveness check (Video Selfie) and proof of address.

### B. Risk Monitoring
- **Limits**: Tontine amount caps based on user KYC level.
- **Honor Score**: Internal algorithm evaluating payment punctuality to prevent contribution defaults.
- **Audit Logs**: Immutable history of every technical transaction stored on Firebase (Secure Firestore).

---

## 4. Technical Architecture & Security

### A. Technology Stack
- **Frontend**: Flutter (Mobile & Web) with Single Source of Truth via Riverpod.
- **Backend**: Firebase Cloud Functions for API secret isolation.
- **Database**: Firestore with restrictive Cloud Security Rules.

### B. Security Measures
- **E2E Encryption**: Private discussions and sensitive documents are AES-256 encrypted before storage.
- **Secrets Management**: No Mangopay keys are stored client-side. All calls go through authenticated server functions.
- **Webhooks**: Real-time synchronization via Mangopay webhooks to confirm PayIn/Payout success.

---

## 5. Regulatory Commitment
Ethical Tontine commits to:
1.  **Inform** its users of the nature of services provided by Mangopay.
2.  **Display** Mangopay's T&Cs explicitly.
3.  **Collaborate** with Mangopay for any investigation or fund freezing request in case of suspected fraud.

---

### Appendices Available on Request
- Detailed flow diagrams (Mermaid/UML).
- API Documentation of Integration Cloud Functions.
- Privacy Policy & GDPR.
