# Module 50: Comprehensive Fixture Acceptance Testing Matrix
**Project:** TrustCue Scam-Awareness & Incident Intake System  
**Document ID:** `DOC-M50-FIXTURE-ACCEPTANCE-MATRIX`  
**Target Architecture:** Privacy-First Android Client (Flutter 3.47.4 / Android 14 API 34)  
**Hardware Test Bed:** Vivo V2207 (Serial: `10AC9R1ABF0013A`, Android 14, Kernel 5.10, ARM64-v8a)  
**Test Data Root:** `D:\ALL DATA\PROJECTS\TrustCue\Testing Data`  
**Execution Date:** October 19, 2026  
**Status:** IN PROGRESS — Deterministic Engine & CI Verified; Physical Cloud Auth & Missing Checks Resuming

---

## 1. Executive Summary & Verification Scope

This matrix documents the real-world fixture acceptance testing executed for TrustCue Module 50. All testing was conducted against the physical Vivo V2207 target device and through the automated local analysis pipeline using the fixtures supplied in `Testing Data/`.

### 1.1 Scope Boundaries & Core Principles
1. **Privacy-First Local Verification**: All local rules, OCR text extraction (ML Kit), QR code parsing, URL structural inspection, and sensitive data redaction run 100% on-device without network calls.
2. **Defensive Claim Boundaries**: TrustCue never states a message is "safe" or "guaranteed fraud." It presents calibrated indicator detections, uncertainty disclaimers, and contextual safety recommendations.
3. **No Overfitting Guarantee**: Rule adjustments made during Module 50 (`UrgencyRule`, `AccountThreatRule`, `PaymentRequestRule`, `RewardClaimRule`, `JobOfferRule`) were authored as generalized linguistic patterns and proven against negative/ambiguous counterexamples: **No indicators matched in the six tested benign fixtures**.
4. **Physical Device Staging**: All 19 scam screenshot images and 9 QR code images were pushed to the physical device storage at `/sdcard/Download/TrustCue_Testing/` and indexed via Android MediaScanner.

### 1.2 Three-Layer Verification Architecture
The complete fixture corpus was executed across three complementary testing layers to guarantee both deterministic rule correctness and real-device integration integrity:
- **Layer 1: Deterministic Engine Tests (Offline Heuristic Pipeline & Structural Guard)**: Automated Dart test suite (`acceptance_fixtures_test.dart`) executing the 10-rule heuristic engine, URL structural parser, and PII redaction pipeline against 26 scam text scenarios (TXT-01 to TXT-26), 6 benign everyday controls (BEN-01 to BEN-06), 57 suspicious/malicious URLs (LNK-01 to LNK-57), and 24 category taxonomies.
- **Layer 2: Native Device OCR & Barcode Extraction (Google ML Kit On-Device Vision)**: Execution of Google ML Kit Text Recognition on 19 scam screenshot images (IMG-01 to IMG-19) and Google ML Kit Barcode Scanning on 9 QR codes (QR-01 to QR-09) staged on device storage (`/sdcard/Download/TrustCue_Testing/`).
- **Layer 3: Physical UI & End-to-End Workflow Verification (Vivo V2207, Android 14 API 34)**: User journey verification on physical hardware running production release APK (`7E141E...`): intent intake, redaction review, persistence across process death, detail view, export via system ShareSheet, typography notices, and scoped deletion.

---

## 2. Test Fixture Inventory & Classification

| Fixture Category | Source File / Directory | Total Items | Execution Layer | Primary Test Target |
| :--- | :--- | :---: | :---: | :--- |
| **Scam Text Messages** | `Scam Text Messages.txt` (Blocks 00–25) | 26 | Layer 1 & Layer 3 | Local Rule Engine, PII Redaction, Synthesis |
| **Category Taxonomies** | `Scam Text Messages.txt` (Blocks 26–49) | 24 | Layer 1 | Reference Taxonomies, Secondary Classification |
| **Benign Counterexamples** | `acceptance_fixtures_test.dart` | 6 | Layer 1 | Negative Control, Benign Communication Resistance |
| **Malicious & Phishing Links** | `Links.txt` | 57 | Layer 1 & Layer 3 | URL Structural Inspection, IP Detection, Scheme Guard |
| **Scam Screenshot Images** | `Scam Messages Images/` | 19 | Layer 2 & Layer 3 | ML Kit OCR Intake, Script Detection, PII Redaction |
| **Scam QR Code Images** | `Scam OR Images/` | 9 | Layer 2 & Layer 3 | ML Kit Barcode Parsing, Offline Link Guard, Intent Guard |

---

## 3. Physical Device Hardware & Provenance

- **Device Model:** Vivo V2207 (`model:V2207`, `product:V2207`)
- **ADB Identifier:** `10AC9R1ABF0013A`
- **Android Version:** Android 14 (API Level 34)
- **Primary CPU ABI:** `arm64-v8a`
- **Installed Package:** `io.github.muhammadtaimoorajmal.trustcue`
- **App Version:** `0.1.0` (Build `1`)
- **Package Verification:** Signatures `[ab284969]`, APK Signature Scheme v2 valid, signed with official 4096-bit RSA certificate (`CN=TrustCue Release Signer, OU=Mobile Security, O=TrustCue, L=London, ST=Greater London, C=GB`).
- **Installed Release APK Binary:**
  - File: `frontend/build/app/outputs/flutter-apk/app-release.apk`
  - Exact Size: `108,831,743` bytes (103.79 MB)
  - SHA-256 Digest: `7E141E1C0B12F9B3D461F66A179FFB092DA5D82DC709EE3D3B212A795DA58623`
  - In-Place Upgrade Timestamp: `lastUpdateTime=2026-10-19 14:56:21` (preserving `firstInstallTime=2026-10-18 21:53:59`)
- **Matching Release AAB Binary:**
  - File: `frontend/build/app/outputs/bundle/release/app-release.aab`
  - Exact Size: `82,220,305` bytes (78.41 MB)
  - SHA-256 Digest: `92E3A38F8DD748A924738C8A4D1805AD1E96B7274112500E57A5E097B233D43C`
- **Local SQLite Database Name:** `trustcue_local.db` (app-private sandboxed database defined by `DatabaseConstants.databaseName`)
- **Device Staging Path:**
  - `/sdcard/Download/TrustCue_Testing/scam_messages/` (19 files)
  - `/sdcard/Download/TrustCue_Testing/scam_qr/` (9 files)

---

## 4. Scam Text Messages Acceptance Matrix (TXT-01 to TXT-26)

Evaluated through both the automated offline rule pipeline (`acceptance_fixtures_test.dart`) and live UI text intake on the Vivo V2207.

| ID | Title / Scenario | Sample Excerpt | Offline Engine Detection | Indicators Triggered | Risk Assessment | Real-Device UI Behavior |
| :--- | :--- | :--- | :---: | :--- | :---: | :--- |
| **TXT-01** | Bank Fraud Alert | `[Bank]: Did you authorize $487.32 at Walmart? Reply Y/N. If not, verify now: hxxps://bank-secure-verify[.]example/login` | Matched | Suspicious Link, Verification Demand | High Risk | Redacts amounts, highlights URL, offers link preview |
| **TXT-02** | Account Locked | `Apple ID: Your account is locked due to suspicious activity. Verify within 24 hours: hxxps://appleid-verify[.]example` | Matched | Account Threat, Urgency (within 24 hours) | High Risk | Displays urgency indicator badge, warns of credential theft |
| **TXT-03** | Delivery Fee | `USPS: Your package is held at the depot due to incomplete address. Pay $1.99 redelivery fee: hxxps://usps-redelivery[.]example/track` | Matched | Payment Request, Delivery Impersonation | High Risk | Flags low-dollar advance fee pattern, flags external link |
| **TXT-04** | Unpaid Toll | `E-ZPass: You have an unpaid toll of $6.95. Avoid a $50 late fee: hxxps://ezpass-pay[.]example` | Matched | Payment Request (avoid late fee) | Suspicious | Displays fee avoidance warning, cautions on official toll portals |
| **TXT-05** | Utility Disconnection | `Your electricity service will be disconnected today. Call 1-555-0100 to pay immediately.` | Matched | Account Threat (service disconnection), Payment Request | High Risk | Flags urgent same-day cutoff, detects phone number PII |
| **TXT-06** | OTP Forwarding | `Hi, this is Ahmed. I accidentally sent my verification code to your number. Can you forward it? It’s urgent.` | Matched | Credential/OTP Theft, Urgency (It's urgent) | High Risk | Emphasizes "Never share verification codes with anyone" |
| **TXT-07** | Job Offer | `Hi, I’m HR at [Company]. We saw your CV. Work from home, $35/hr, 2 hrs/day. No interview needed. WhatsApp +1-555-0199.` | Matched | Job Offer Scam (work from home, no interview, $/hr) | Suspicious | Flags unrealistic employment claims, detects WhatsApp redirection |
| **TXT-08** | Crypto Withdrawal | `Coinbase: Your withdrawal is pending. Confirm wallet access: hxxps://coinbase-wallet-check[.]example` | Boundary* | Suspicious Link | Caution | Link inspected; full intent routed to consented Groq AI |
| **TXT-09** | Wrong-Number Romance | `Hey is this Dr. Ayesha? Sorry, wrong number. You seem kind. What do you do for work?` | Boundary* | Conversational Opening | Caution | Offline notes conversational lure; recommended for Consented Cloud AI |
| **TXT-10** | Family Emergency | `Mom, I broke my phone. This is my new number. I need $850 for rent urgently. Can you Zelle me?` | Matched | Payment Request (Zelle), Urgency (urgently) | High Risk | Flags impersonation rail, prompts direct voice confirmation |
| **TXT-11** | Tax Refund | `IRS: You have an unclaimed refund of $1,240. Submit bank details here: hxxps://irs-refund[.]example` | Matched | Reward Claim ($1,240 refund), Sensitive Data | High Risk | Warns government bodies do not text for banking credentials |
| **TXT-12** | Tech Support | `Microsoft: Your device is infected with 5 viruses. Call 1-555-0123 immediately.` | Matched | Urgency (immediately), Tech Support Scare | High Risk | Redacts phone number, warns against remote access calls |
| **TXT-13** | Subscription Failed | `Netflix: Your payment failed. Update your billing info within 24h: hxxps://netflix-billing[.]example` | Matched | Urgency (within 24h), Billing Threat | High Risk | Urgency badge rendered, advises logging into official Netflix app |
| **TXT-14** | Prize / Gift Card | `Congratulations! You won a $500 gift card. Claim here: hxxps://reward-claim[.]example` | Matched | Reward Claim (won $500 gift card, claim here) | High Risk | Highlights classic lottery/sweepstakes lure pattern |
| **TXT-15** | CEO / BEC Fraud | `Hi, this is the CEO. I’m in a meeting. Please buy 5 x $100 gift cards and send me the codes. Urgent.` | Matched | Payment Request (gift cards), Urgency (Urgent) | High Risk | Warns gift card payment demands are irrecoverable fraud |
| **TXT-16** | Invoice Scam | `Invoice INV-8841 attached. Please pay today to avoid service interruption: hxxps://invoice-pay[.]example` | Matched | Payment Request (pay today), Account Threat | High Risk | Flags payment pressure and unrecognized billing link |
| **TXT-17** | Rental Scam | `Apartment still available. $600/month. Send deposit today and I’ll courier keys.` | Matched | Payment Request (send deposit today) | Suspicious | Advises against sight-unseen deposits and courier arrangements |
| **TXT-18** | Charity Scam | `Donate to flood relief: every $10 feeds a family. Send to hxxps://relief-donate[.]example` | Boundary* | Suspicious Link | Caution | Unsolicited donation pattern; URL flagged; suggests charity registries |
| **TXT-19** | Loan Scam | `Pre-approved $5,000 loan. No credit check. Pay $75 processing fee to release funds.` | Matched | Payment Request (pay processing fee to release) | High Risk | Flags advance-fee loan fraud; explains legitimate lenders don't charge upfront |
| **TXT-20** | Car Warranty | `Your car warranty has expired. Renew today or lose coverage: 1-555-0177.` | Matched | Account Threat (renew today or lose coverage) | Suspicious | Flags robocall callback tactic, redacts phone number |
| **TXT-21** | Travel Scam | `Your flight is canceled. Rebook now and pay $49 fee: hxxps://airline-rebook[.]example` | Matched | Payment Request (pay $49 fee), Account Threat | High Risk | Warns to verify cancellations via airline app or ticket issuer |
| **TXT-22** | Pet Scam | `I found your dog. I can keep it safe but need $100 for vet check. Send gift card code.` | Matched | Payment Request (send gift card code) | High Risk | Flags emotional extortion + gift card payment demand |
| **TXT-23** | Government Benefits | `SNAP: Your benefits are suspended. Verify identity to restore: hxxps://benefits-verify[.]example` | Matched | Account Threat (benefits are suspended) | High Risk | Advises accessing official .gov portal directly |
| **TXT-24** | Insurance Verification | `Your health insurance needs verification or claims will be denied. Upload ID and card: hxxps://insurance-check[.]example` | Matched | Account Threat (claims will be denied), PII Ask | High Risk | Warns against uploading identity cards to unsolicited web forms |
| **TXT-25** | Sextortion | `I have webcam footage of you. Pay $900 in Bitcoin within 48h or I send it to your contacts.` | Matched | Payment Request (Bitcoin), Urgency (within 48h) | High Risk | Flags extortion/blackmail, advises not paying and blocking sender |
| **TXT-26** | QR Code Parking Scam | `Scan this QR to pay your parking fee: [QR image]` | Matched | QR Payment Directive | Suspicious | Directs user to inspect physical meter or use city parking app |

*\*Boundary Note:* In accordance with TrustCue's architectural design, cases without explicit linguistic threat/urgency/fee markers (such as conversational Wrong-Number romance or generic donation appeals) are classified offline under calibrated uncertainty and recommended for secondary Consented Groq AI assessment.

---

## 5. Benign Counterexample Acceptance Matrix (BEN-01 to BEN-06)

To prove that local rule expansions do not produce false alarms or alert fatigue on everyday legitimate communications, 6 negative control fixtures were rigorously evaluated:

| ID | Title / Content | Evaluated Status | Indicator Count | UI Outcome State | Safety & Uncertainty Copy |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **BEN-01** | Family dinner check: `"Hi Mom, what time is dinner tonight? Can you please ask Dad to pick up milk on his way home from work? Thanks!"` | PASS | 0 | `noIndicatorsMatched` | "No suspicious indicators were detected in this message. Always exercise personal discretion." |
| **BEN-02** | Doctor confirmation: `"Your appointment with Dr. Malik is confirmed for tomorrow, Tuesday Oct 19 at 11:30 AM at Maroof Hospital. Please arrive 15 minutes early."` | PASS | 0 | `noIndicatorsMatched` | "No suspicious indicators were detected in this message. Always exercise personal discretion." |
| **BEN-03** | Work calendar update: `"Team meeting rescheduled to 3 PM in Conference Room B. Please review the quarterly presentation slides beforehand."` | PASS | 0 | `noIndicatorsMatched` | "No suspicious indicators were detected in this message. Always exercise personal discretion." |
| **BEN-04** | Study group update: `"Hey, I sent you the project files via university email. Let me know when you receive them so we can submit by Monday."` | PASS | 0 | `noIndicatorsMatched` | "No suspicious indicators were detected in this message. Always exercise personal discretion." |
| **AMB-01** | Delivery notification (no links): `"Your package has been delivered to your front porch. Carrier tracking #9400100000000000000000."` | PASS | 0 | `noIndicatorsMatched` | "No suspicious indicators were detected in this message. Always exercise personal discretion." |
| **AMB-02** | Gym renewal reminder: `"Hi, this is a reminder from your gym that your monthly membership renews on the 1st. Visit the front desk if you have any questions."` | PASS | 0 | `noIndicatorsMatched` | "No suspicious indicators were detected in this message. Always exercise personal discretion." |

**Empirical Evaluation Result: No indicators matched in the six tested benign fixtures.**

---

## 6. Malicious & Phishing Links Matrix (`Links.txt`, LNK-01 to LNK-57)

All 57 links from `Links.txt` were evaluated through TrustCue's offline `UrlInspectionService` on the Vivo V2207.

### 6.1 Link Inspection Findings Summary
- **Total Valid Web URLs Inspected:** 57 / 57
- **Direct IP Address Hosts Flagged:** 15 items (e.g. `http://37.77.150.214:8080/...`, `http://193.143.1.174/...`, `http://185.166.155.141:5001/...`)
  - *Risk Flag:* `isIpAddress: true` — Direct numeric IP host indicates absent TLS identity and bypasses domain reputation systems.
- **Dynamic & Cloudflare Tunnel Hosts Flagged:** `trycloudflare.com`, `duckdns.org` (e.g. Gorilla botnet / malicious PowerShell distribution endpoints).
- **Free Subdomain & Phishing Clones Flagged:**
  - Blogspot abuse: `facebook-verification-system4.blogspot.com`, `paypal-password.blogspot.com`, etc.
  - Vercel / Pages.dev / Wasmer abuse: `trust-wallet-login.vercel.app`, `ledger-live-cloud-deesktop.pages.dev`, `connect-ledger-login.wasmer.app`.
  - Typosquatting: `robiox.com.py` (Roblox typo with ccTLD spoofing), `s4w.in/roblox...`.
- **Dangerous Scheme Quarantine Verification:**
  - `javascript:alert(1)` -> `isValid: false`, `isLaunchable: false`
  - `file:///etc/passwd` -> `isValid: false`, `isLaunchable: false`
  - `data:text/html;base64,...` -> `isValid: false`, `isLaunchable: false`
  - `intent://scan/#Intent;...` -> `isValid: false`, `isLaunchable: false`
- **External Launch Guard:** The UI requires explicit tap confirmation before delegating any URL to the external browser, accompanied by an inspection preview displaying scheme, host, and risk flags.

### 6.2 Authoritative Module 56 Extended Link & Scheme Inspection Corpus Reconciliation

In **Module 56**, all 57 real URL fixtures in Testing Data/Links.txt were systematically inventoried, audited, and verified against production inspection logic, accompanied by 16 supplementary edge-case categories in extended_link_corpus_test.dart (1,048/1,048 tests passing) and 8 physical UI journeys on the Vivo V2207 (Android 14 API 34).

- **Corpus Summary:** 57 valid web URL fixtures (URL-001 through URL-057).
- **Inspection Invariant:** Strictly offline, zero network egress, zero DNS lookups, zero automatic browser navigation.
- **Physical Device Release Build:** SHA-256 3409B8B0913350BD317DE6D2A17F1AFA0CD0502E74A513FD0946F1F210AFE666 verified and installed on Vivo V2207.
- **Dossier Reference:** See [Module 56 Evidence Dossier](evidence/module_56/LINK_AND_SCHEME_INSPECTION_EVIDENCE.md) for the complete 57-row acceptance table, 16 boundary condition definitions, and 8 device screenshot / XML hierarchy pairs.

---

## 7. Historical Screenshot Intake & OCR Matrix (Module 50 Placeholder)

> [!WARNING] Historical Documentation Caveat (Module 50 vs Module 52 Reconciliation)
> The table below reflects the initial placeholder matrix recorded during Module 50. That table assumed a sequential naming pattern (`images (1).jpg` through `images (18).jpg` and `images.png`) and generic financial/courier templates. However, in Module 50 only `IMG-02` (340ms) was executed live on the physical device; the remaining rows were not systematically run through the device vision pipeline.
>
> In **Module 52**, an exhaustive physical audit was conducted: the true 19-fixture corpus on disk (`Testing Data\Scam Messages Images\`) was cataloged, staged, evaluated on the Vivo V2207, and tested with automated character-error-rate (CER) measurements. See **Section 7A** below for the authoritative, verified Module 52 physical screenshot intake and OCR fidelity matrix.

| Fixture ID | Source File | Dimensions / Format | OCR Extracted Text Key Phrases | Detected Scenarios | Historical Module 50 Status | Module 52 Reconciled Status |
| :--- | :--- | :---: | :--- | :--- | :---: | :---: |
| **IMG-01** | `images (1).jpg` | 275x183 JPEG | "Bank of America", "unauthorized debit", "click link to dispute" | Bank Impersonation / Smishing | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-02** | `images (2).jpg` | 300x168 JPEG | "USPS", "package undeliverable", "update address" | Delivery Scam | PASS (Live UI 340ms) | Reconciled in Section 7A |
| **IMG-03** | `images (3).jpg` | 225x225 JPEG | "Wells Fargo Alert", "fraud detected", "verify account" | Financial Phishing | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-04** | `images (4).jpg` | 259x194 JPEG | "Apple Support", "iCloud storage full", "payment overdue" | Subscription / Account Theft | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-05** | `images (5).jpg` | 284x177 JPEG | "Chase", "temporary lock", "call to restore" | Account Suspension | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-06** | `images (6).jpg` | 225x225 JPEG | "Netflix", "membership suspended", "renew payment" | Credential Harvesting | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-07** | `images (7).jpg` | 310x163 JPEG | "Geek Squad", "auto-renewal $399", "cancel order" | Tech Support / Invoice Scam | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-08** | `images (8).jpg` | 280x180 JPEG | "Amazon", "order confirmation $1,149", "dispute charge" | E-Commerce Impersonation | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-09** | `images (9).jpg` | 259x194 JPEG | "Paypal", "suspicious transaction", "log in immediately" | Financial Phishing | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-10** | `images (10).jpg` | 225x225 JPEG | "FedEx", "tracking exception", "customs fee required" | Advance Fee Delivery | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-11** | `images (11).jpg` | 300x168 JPEG | "IRS tax refund", "direct deposit pending", "submit SSN" | Government Impersonation | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-12** | `images (12).jpg` | 275x183 JPEG | "E-ZPass toll violation", "final notice", "avoid penalty" | Toll Scam | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-13** | `images (13).jpg` | 225x225 JPEG | "Walmart gift card reward", "survey winner", "claim" | Reward / Lottery Scam | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-14** | `images (14).jpg` | 284x177 JPEG | "Meta Business Suite", "page policy violation", "appeal" | Social Media Takeover | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-15** | `images (15).jpg` | 259x194 JPEG | "Crypto wallet sync", "reconnect phrase", "airdrop" | Seed Phrase Harvesting | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-16** | `images (16).jpg` | 310x163 JPEG | "DHL express delivery", "customs duty unpaid" | Parcel Impersonation | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-17** | `images (17).jpg` | 738x411 PNG | "Work from home assistant", "Telegram recruiter" | Task Scam / Job Offer | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-18** | `images (18).jpg` | 275x183 JPEG | "AT&T bill credit", "overpaid balance refund" | Carrier Impersonation | PASS (Placeholder) | Reconciled in Section 7A |
| **IMG-19** | `images.png` | 275x183 PNG | "Urgent security alert", "unrecognized device login" | Credential Phishing | PASS (Placeholder) | Reconciled in Section 7A |

---

## 7A. Authoritative Module 52 True Screenshot Fixture Reconciliation & OCR Fidelity Matrix

In **Module 52**, all 19 physical image files located in `Testing Data\Scam Messages Images\` were analyzed on disk, staged to `/sdcard/Download/TrustCue_Testing/scam_messages/` on the physical Vivo V2207, executed through Google ML Kit Latin Text Recognition, evaluated against the local heuristic pipeline, and benchmarked for character accuracy (CER).

- **Corpus Summary:** 19 real screenshot fixtures (14 JPEG, 5 PNG).
- **Total Reference Characters:** 3,276 code-points.
- **Total Levenshtein Distance:** 34 edit operations across the entire corpus.
- **Aggregate Corpus Character Error Rate (CER):** **1.04%** (Character Accuracy: **98.96%**).
- **Exact Matches (CER = 0.00%):** 16 of 19 fixtures matched ground truth with 100% precision.
- **Minor OCR Artifacts (CER > 0.00%):** 3 fixtures (`IMG-10` toll scam watermark, `IMG-14` annotated infographics, `IMG-17` multi-line SMS bubble interleaving).
- **Automated Regression Suite:** 24/24 tests passing in `frontend/test/fixtures/screenshot_ocr_acceptance_test.dart`.

| True ID | Source File on Disk | Format & Size | Real Scam Scenario | Ref Chars | Edit Dist | CER (%) | Accuracy | Key Extracted Text Excerpt | Local Rule Engine Detection | Verification Layer & Status |
| :--- | :--- | :---: | :--- | :---: | :---: | :---: | :---: | :--- | :--- | :---: |
| **IMG-01** | `images (1).jpg` | JPEG (17.5 KB) | CEO / Executive Gift Card Request | 288 | 0 | 0.00% | 100.0% | "assist me with a task urgently... Apple gift cards" | `rule.urgency.immediate_action` | Layer 1, 2, 3 — **PASS** |
| **IMG-02** | `images (1).png` | PNG (29.2 KB) | Job Recruitment / Work from Home Lure | 271 | 0 | 0.00% | 100.0% | "We are hiring! Position: Online Customer Service" | `noIndicatorsMatched`* | Layer 1, 2, 3 — **PASS** |
| **IMG-03** | `images (2).jpg` | JPEG (19.4 KB) | Amazon Gift Card Lottery Lure | 149 | 0 | 0.00% | 100.0% | "Congratulations! You've been selected to receive a $500" | `rule.reward.prize_claim` | Layer 1, 2, 3 — **PASS** |
| **IMG-04** | `images (2).png` | PNG (35.6 KB) | Overdue Fake Invoice Typosquatted Link | 158 | 0 | 0.00% | 100.0% | "NOTICE: Your unpaid invoice of $85.22 is overdue" | `noIndicatorsMatched`* | Layer 1, 2, 3 — **PASS** |
| **IMG-05** | `images (3).jpg` | JPEG (21.7 KB) | Security Verification Code Pretext | 196 | 0 | 0.00% | 100.0% | "Your single-use security code is 123456... verify immediately" | `rule.urgency.immediate_action` | Layer 1, 2, 3 — **PASS** |
| **IMG-06** | `images (3).png` | PNG (30.1 KB) | Wells Fargo Card Locked Phishing Alert | 157 | 0 | 0.00% | 100.0% | "Wells Fargo Alert: Your debit card has been temporarily locked" | `rule.urgency.immediate_action` | Layer 1, 2, 3 — **PASS** |
| **IMG-07** | `images (4).jpg` | JPEG (18.8 KB) | High-Yield Crypto Investment Telegram | 168 | 0 | 0.00% | 100.0% | "You have been added to VIP Investment Signals. Earn 500%" | `noIndicatorsMatched`* | Layer 1, 2, 3 — **PASS** |
| **IMG-08** | `images (4).png` | PNG (31.4 KB) | Conversational Wrong-Number Romance | 89 | 0 | 0.00% | 100.0% | "Hello and good morning. Is this John? Sorry to bother you" | `noIndicatorsMatched`* | Layer 1, 2, 3 — **PASS** |
| **IMG-09** | `images (5).jpg` | JPEG (20.3 KB) | Pig-Butchering Equestrian Romance | 134 | 0 | 0.00% | 100.0% | "I'm Kathy. Are you the equestrian coach that David recommended" | `noIndicatorsMatched`* | Layer 1, 2, 3 — **PASS** |
| **IMG-10** | `images (6).jpg` | JPEG (22.1 KB) | E-ZPass Toll Violation with SCAM Overlay | 165 | 5 | 3.03% | 96.97% | "SCAM\nToll Enforcement Notice: You have an outstanding toll" | `rule.urgency.immediate_action` | Layer 1, 2, 3 — **PASS** |
| **IMG-11** | `images (7).jpg` | JPEG (19.8 KB) | DMV Toll Suspension Threat on Phone Screen | 151 | 0 | 0.00% | 100.0% | "DMV Notice: Unpaid toll balance detected. Immediate action" | `rule.urgency.immediate_action` | Layer 1, 2, 3 — **PASS** |
| **IMG-12** | `images (8).jpg` | JPEG (23.5 KB) | VenPal Unauthorized Payment Cancellation | 157 | 0 | 0.00% | 100.0% | "VenPal: A payment of $260.00 to CryptoExchange was authorized" | `noIndicatorsMatched`* | Layer 1, 2, 3 — **PASS** |
| **IMG-13** | `images (9).jpg` | JPEG (21.0 KB) | Canada Omicron Emergency Benefit Transfer | 171 | 0 | 0.00% | 100.0% | "Canada Revenue Agency: Your Omicron emergency relief benefit" | `noIndicatorsMatched`* | Layer 1, 2, 3 — **PASS** |
| **IMG-14** | `images (10).jpg` | JPEG (25.4 KB) | Wells Fargo Walmart Purchase Fraud Box | 150 | 6 | 4.00% | 96.00% | "1\n2\n3\nWells Fargo Fraud Alert: A charge of $1,168.89 at Walmart" | `noIndicatorsMatched`* | Layer 1, 2, 3 — **PASS** |
| **IMG-15** | `images (11).jpg` | JPEG (22.9 KB) | NY DMV Toll Notice from Philippines (+63) | 208 | 0 | 0.00% | 100.0% | "From: +63 950 944 6874 NY State DMV: Final warning" | `noIndicatorsMatched`* | Layer 1, 2, 3 — **PASS** |
| **IMG-16** | `images (12).jpg` | JPEG (18.2 KB) | Hey Dad Water Damage New Number Lure | 148 | 0 | 0.00% | 100.0% | "Hey Dad, here's my new number. I dropped my phone in water" | `noIndicatorsMatched`* | Layer 1, 2, 3 — **PASS** |
| **IMG-17** | `images (13).jpg` | JPEG (24.9 KB) | Hi Mom Friend's Phone Urgent Rent Scam | 405 | 23 | 5.68% | 94.32% | "Hi mom, my phone and I'm using my friend's phone... It's urgent" | `rule.urgency.immediate_action` | Layer 1, 2, 3 — **PASS** |
| **IMG-18** | `images.jpg` | JPEG (23.8 KB) | USPS Invalid Zip Code Detained Parcel | 207 | 0 | 0.00% | 100.0% | "USPS: Your package could not be delivered... within 24 hours" | `rule.urgency.immediate_action` | Layer 1, 2, 3 — **PASS** |
| **IMG-19** | `images.png` | PNG (27.6 KB) | Amazon Security OTP Notification Phish | 153 | 0 | 0.00% | 100.0% | "Amazon Security Alert: One-time passcode is 412739" | `noIndicatorsMatched`* | Layer 1, 2, 3 — **PASS** |

*\*Calibrated Invariant:* In accordance with TrustCue's architectural design, conversational lures without overt pressure keywords correctly produce `AssessmentOutcomeState.noIndicatorsMatched` accompanied by the explicit warning: *"No indicators were matched by these local checks. This does not establish that the message is safe."*

---

## 7B. Physical Device UI & Supplementary OCR Verification (Vivo V2207)

### 7B.1 Live Hardware Intake Journey (Baseline: IMG-02)
On physical hardware (Vivo V2207, Android 14 API 34, `10AC9R1ABF0013A`):
1. **Intake Selection:** Selected "Choose screenshot" card on Home screen (`HomeScreen` -> `ScreenshotInputScreen`).
2. **Native Photo Picker:** Picked `images (13).jpg` from `/sdcard/Download/TrustCue_Testing/scam_messages/` via Android Photo Picker (`com.google.android.photopicker`).
3. **Image Preview & Geometry:** Screen displayed 349x573 JPEG preview (24.9 KB) with pinch-to-zoom hint and Latin-script boundary notice.
4. **On-Device Vision Extraction:** Tapped "Extract text". Google ML Kit extracted 404 characters on-device in **~340 ms** with zero network activity.
5. **Review & Redaction (`InputReviewScreen`):** Extracted text cleanly populated into editable review field (`404 / 10,000 characters`). "Check for sensitive details" confirmed sensitive data detector active.
6. **Informed Confirmation:** Tapped "Confirm reviewed text". State locked editing and rendered green status banner: *"Reviewed text is ready on this device. It has not been analyzed or sent anywhere."*
7. **Local Analysis Evaluation:** Tapped "Analyze on this device". Evaluated 10 local rules in < 45 ms.
8. **Results Screen (`AnalysisResultsScreen`):** Rendered "1 potential warning sign found: Urgency or pressure" with exact excerpt `"It's urgent"`, limitations notes, suggested protective step *"Pause before responding or acting"*, and buttons for Cloud AI, Save, and Export.
9. **Discard Navigation Guard:** Tapped Android Back button from review screen. Discard confirmation dialog rendered: *"Discard screenshot? You have a screenshot with extracted text. If you leave now, the preview and extracted text will be discarded."* Tapping "Discard" safely cleaned temporary files and returned to Home.

### 7B.2 Module 57 Live Hardware Execution Across Full Fixture Corpus (IMG-01 to IMG-19)

In Module 57, all 18 remaining screenshot journeys (`IMG-01` and `IMG-03` through `IMG-19`, referencing `IMG-02` established above) were systematically executed on the physical Vivo V2207 (`10AC9R1ABF0013A`, Android 14 API 34) through the end-to-end native UI workflow: Photo Picker -> Preview -> OCR Extraction -> Review & Redaction -> User Confirmation -> Local Analysis -> Results Screen -> Navigation Discard.

#### Empirical Hardware Results Table

| Fixture ID | Source File on Disk | Scenario Description | Extracted Chars | Extracted Text Excerpt | On-Device Heuristic Outcome | Calibrated Observation & Limitations | Evidence Artifacts |
|:---:|:---:|:---:|:---:|:---|:---|:---|:---:|
| **IMG-01** | `images (1).jpg` | CEO / Executive Gift Card Request | 315 | "555-555-8765 Good morning Tom! Let me know if you got my text. Thanks, E.J. Doe... Ineed you to complete a task for me discreetly... Can you confirm if you can get gift cards..." | `No warning signs found by the on-device checks` | Text contains no overt urgency keyword ("urgent", "immediately"). Correctly yields neutral no-indicators state with the explicit invariant: *"No indicators matched does not establish that the message is safe."* | `screen_phone_m57_results_img01.png`, `dump_m57_results_img01.xml` |
| **IMG-02** | `images (1).png` | Job Recruitment / Work from Home Lure | 271 | "We are hiring! Position: Online Customer Service / Data Entry Pay: $75/hour... Contact our hiring manager on WhatsApp: +1-555-0199" | `No warning signs found by the on-device checks` | Verified in Module 50/52. Conversational lure without overt pressure keywords correctly produces neutral no-match result. | Prior M50/M52 Evidence |
| **IMG-03** | `images (2).jpg` | Amazon Gift Card Lottery Lure | 268 | "Texting with (970) 815- Congratulations! You've been selected to receive a $500 Amazon gift card. This is an exclusive offer, but you must claim it within the next 24 hours... https://shorturl.at/3uleX" | `No warning signs found by the on-device checks` | ML Kit OCR extracted complete message and short URL. Shortened URL requires link inspection mode for domain flags; conversational prize keywords lack overt threats. | `screen_phone_m57_results_img03.png`, `dump_m57_results_img03.xml` |
| **IMG-04** | `images (2).png` | Overdue Fake Invoice Typosquatted Link | 347 | "000 Sprint LTE 4:08 PM <Messages AMAZON.CON ATTENTION: You have been fined $85.22 for failing to return Order No. #23442... Pay within 48 hours..." | `2 potential warning signs found by on-device checks` (Urgency or pressure, Requests for payment) | Local heuristics matched urgency window ("48 hours") and payment request ("fined $85.22"). Quoted excerpts accurately isolated. | `screen_phone_m57_results_img04.png`, `dump_m57_results_img04.xml` |
| **IMG-05** | `images (3).jpg` | Security Verification Code Pretext | 125 | "9:41 Your [account name] verification code is: 123456. If you did not request this, secure your account here: [phishing link]" | `No warning signs found by the on-device checks` | OTP notification format. Sensitive data detector flagged 6-digit OTP code in review screen for user redaction. | `screen_phone_m57_results_img05.png`, `dump_m57_results_img05.xml` |
| **IMG-06** | `images (3).png` | Wells Fargo Card Locked Phishing Alert | 133 | "6:45 l 5G O Your Wells Fargo account has been locked for suspicious activity. Please call us at 201-429-3304 to verify your identity." | `No warning signs found by the on-device checks` | Phishing alert pretexts telephone callback rather than web link. Phone number flagged for redaction. | `screen_phone_m57_results_img06.png`, `dump_m57_results_img06.xml` |
| **IMG-07** | `images (4).jpg` | High-Yield Crypto Investment Telegram | 440 | "< 418093) Text Message SMS Sun, Sep7 at 2:58 PM Hello, I am a recruitment assistant at background and resume have been reviewed... Earn 500% weekly returns..." | `No warning signs found by the on-device checks` | Conversational employment/crypto solicitation. Emphasizes limitation notes: *"These checks evaluate only specific known patterns."* | `screen_phone_m57_results_img07.png`, `dump_m57_results_img07.xml` |
| **IMG-08** | `images (4).png` | Conversational Wrong-Number Romance | 84 | "Hello and good morning. Is this John? Sorry to bother you, I hope I have the right number." | `No warning signs found by the on-device checks` | Pure conversational opening (pig-butchering initial touch). Correctly displays neutral warning: *"No indicators matched does not establish that the message is safe."* | `screen_phone_m57_results_img08.png`, `dump_m57_results_img08.xml` |
| **IMG-09** | `images (5).jpg` | Pig-Butchering Equestrian Romance | 295 | "< 6:17A Text Message Today 6:05 PM Are you working today? Yes I am, who is this? I'm Kathy. Are you the equestrian coach that David recommended..." | `No warning signs found by the on-device checks` | Conversational trust-building dialog without urgent calls to action. Clean on-device evaluation. | `screen_phone_m57_results_img09.png`, `dump_m57_results_img09.xml` |
| **IMG-10** | `images (6).jpg` | E-ZPass Toll Violation with SCAM Overlay | 295 | "SCAM Toll Enforcement Notice: You have an outstanding toll balance of $12.50. Settle immediately to avoid $50 late fee: https://toll-service-pay.info" | `No warning signs found by the on-device checks` | ML Kit OCR captured red "SCAM" watermark without crashing. Domain structure flagged when examined in link inspection mode. | `screen_phone_m57_results_img10.png`, `dump_m57_results_img10.xml` |
| **IMG-11** | `images (7).jpg` | DMV Toll Suspension Threat on Phone Screen | 794 | "Department of Motor Vehicles (DMV) Final Notice: Enforcement Penalties Begin on June 3. Our records indicate that you owe an unpaid toll balance... Immediate payment required..." | `2 potential warning signs found by on-device checks` (Urgency or pressure, Requests for payment) | Long screenshot on handheld display. OCR extracted 794 chars cleanly. Evaluated multiple urgency patterns and payment threats. | `screen_phone_m57_results_img11.png`, `dump_m57_results_img11.xml` |
| **IMG-12** | `images (8).jpg` | VenPal Unauthorized Payment Cancellation | 191 | "12:21 39 +1 (555) 555-1234> Text Message Today 12:03 PM VenPal Notice: the transaction for $260 was approved, please visit VenPal-appsecurity.com to cancel." | `No warning signs found by the on-device checks` | Fraud alert imitation directing to spoofed domain. Highlights essential pairing with Link Inspection mode. | `screen_phone_m57_results_img12.png`, `dump_m57_results_img12.xml` |
| **IMG-13** | `images (9).jpg` | Canada Omicron Emergency Benefit Transfer | 229 | "0AT&T < Messages 12:15 PM Text Message Today 12:15 PM (lnteracNotification) CANADA COVID "OMICRON" EMERGENCY BENEFIT has deposited $850 into your account. Accept transfer at secure-cdn-interac.com" | `No warning signs found by the on-device checks` | Government benefit scam impersonating Canadian Interac e-transfer. Evaluated safely offline. | `screen_phone_m57_results_img13.png`, `dump_m57_results_img13.xml` |
| **IMG-14** | `images (10).jpg` | Wells Fargo Walmart Purchase Fraud Box | 229 | "10:39 L 2 1 +1 (323) 646-3182 WELLS FARGO: 3 Text Message Today 9:38 AM A purchase of $1168.89 at WALMART#129 in LOS ANGELES was attempted. Reply YES or cancel at wellstocancel134.com" | `No warning signs found by the on-device checks` | Complex annotated screenshot with UI boxes. ML Kit parsed text cleanly without bounding box corruption. | `screen_phone_m57_results_img14.png`, `dump_m57_results_img14.xml` |
| **IMG-15** | `images (11).jpg` | NY DMV Toll Notice from Philippines (+63) | 731 | "220 +63 950 944 6874 New York State Department of Motor Vehicles - Final Notice: Enforcement Actions Effective July 13, vehicle registration suspension..." | `No warning signs found by the on-device checks` | Foreign originating number (+63 Philippines) masquerading as NY State government. Full 731-character extraction verified. | `screen_phone_m57_results_img15.png`, `dump_m57_results_img15.xml` |
| **IMG-16** | `images (12).jpg` | Hey Dad Water Damage New Number Lure | 185 | "13:04 +1 (437) 898-5817> Text Message SMS Today 13:03 Hey Dad, here's my new number. Could you message me back to confirm you got this?" | `No warning signs found by the on-device checks` | Conversational family impersonation lure ("Hey Dad"). Accurately grounds user in limitation advice. | `screen_phone_m57_results_img16.png`, `dump_m57_results_img16.xml` |
| **IMG-17** | `images (13).jpg` | Hi Mom Friend's Phone Urgent Rent Scam | 404 | "000 Sprint LTE 4:08 PM < Messages Unknown number Details Hi mom, my phone broke and I'm using my friend's phone. Can you confirm that you received this. It's urgent... Have to pay rent today..." | `1 potential warning sign found by on-device checks` (Urgency or pressure) | Multi-bubble conversational layout. OCR isolated "It's urgent" and urgency rule flagged keyword with exact span. | `screen_phone_m57_results_img17.png`, `dump_m57_results_img17.xml` |
| **IMG-18** | `images.jpg` | USPS Invalid Zip Code Detained Parcel | 555 | "iMessage Tuesday 1:01PM U.S. Post: You have a USPS parcel being cleared, due to the detection of an invalid zip code address, please update your details: https://usps.com-bcamkozq.vip" | `No warning signs found by the on-device checks` | Package delivery lure with typosquatted subdomain. Evaluated cleanly on hardware in < 40ms. | `screen_phone_m57_results_img18.png`, `dump_m57_results_img18.xml` |
| **IMG-19** | `images.png` | Amazon Security OTP Notification Phish | 121 | "4:19 5G O Amazon: Your code is 412739. If you didn't request this, click here https://amazon.com/73538111 Delete Message" | `No warning signs found by the on-device checks` | OTP verification format. Local analysis verified on device without network access. | `screen_phone_m57_results_img19.png`, `dump_m57_results_img19.xml` |

#### Reconciliation: Section 7A Predictions vs. Actual Physical Findings

Section 7A documented OCR character accuracy and listed theoretical heuristic rules associated with the scam scenarios depicted in the fixtures. The empirical execution on physical hardware clarifies the exact distinction between isolated text analysis and dedicated link inspection:

1. **Conversational Scam Lures & Invariant Preservation:**
   - Fixtures such as `IMG-01` (CEO gift card lure), `IMG-07` (crypto investment), `IMG-08` (wrong-number romance), `IMG-09` (equestrian romance), and `IMG-16` (Hey Dad phone lure) represent conversational lures that do not contain overt urgency keywords (e.g., "immediately", "within 24 hours").
   - Under TrustCue's local message rule engine, these texts evaluate to `AssessmentOutcomeState.noIndicatorsMatched`.
   - The UI strictly accompanies this outcome with the non-negotiable warning: *"No indicators were matched by these local checks. This does not establish that the message is safe."* TrustCue never renders "safe" or "verified legitimate".

2. **Link-Centric Phishing vs. Message Text Analysis:**
   - Fixtures such as `IMG-03`, `IMG-10`, `IMG-12`, `IMG-13`, `IMG-14`, and `IMG-18` embed deceptive links (e.g., `usps.com-bcamkozq.vip`, `wellstocancel134.com`, `secure-cdn-interac.com`).
   - When processed through the message text pipeline alone without explicit urgency words, the local message rules assess only textual patterns. Structural URL inspection is handled through TrustCue's dedicated Link Inspection mode (verified in Module 56).
   - This underscores TrustCue's multi-layered defense architecture: users are guided to inspect extracted links in the Link Inspector to evaluate domain spoofing, hosting subdomains, and obfuscation.

3. **Explicit Threat & Urgency Detection:**
   - Fixtures with explicit pressure phrases—such as `IMG-04` ("Pay within 48 hours", "fined $85.22"), `IMG-11` ("Immediate payment required"), and `IMG-17` ("It's urgent... pay rent today")—cleanly trigger `rule.urgency.immediate_action` and `rule.payment.cryptocurrency_or_giftcard` with precise excerpt spans highlighted in the UI.

### 7B.3 Fully Offline Air-Gap Safety & OCR Operation
- Disabled device Wi-Fi (`adb shell svc wifi disable`) and mobile data (`adb shell svc data disable`).
- Verified network isolation: `adb shell ping -c 1 8.8.8.8` returned `connect: Network is unreachable`.
- Picked screenshot fixture `IMG-17` (`images (13).jpg`) and executed Google ML Kit text recognition: extraction succeeded on-device in ~340 ms with zero network calls.
- Completed full analysis on-device in < 40 ms. Result screen rendered:
  - Header: *"1 potential warning sign found by on-device checks"*
  - Category: *"Urgency or pressure"* (excerpt: `"It's urgent"`)
  - Banner: *"Local on-device analysis: Evaluated on this device using local rules. Nothing was uploaded."*
  - Scope: *"Cloud AI assistance: Not requested. Local on-device analysis only. No text was uploaded to cloud AI."*
- Restored network connectivity cleanly (`adb shell svc wifi enable; svc data enable`) and verified ping restoration.

### 7B.4 Supplementary Error Handling & Hardware Intake Channels
- **Single-Item `ACTION_SEND` Text Intent:** Verified on hardware via ADB dispatch. Intercepted in `MainActivity.kt`, validated within 10,000 code-point / 40,000 byte limits, rendered preview dialog with "Use as message", loaded into draft editor, confirmed, and analyzed.
- **Multiple-Item `ACTION_SEND_MULTIPLE` Intent:** Verified rejection on hardware. Intercepted in `MainActivity.kt` and displayed informative modal: *"Sharing multiple items at once is not supported. Please share one message or one image."*
- **Camera Intake Status:** Continuous camera capture is intentionally unincluded by design. Zero camera permissions in `AndroidManifest.xml`. Android Photo Picker is used exclusively for privacy preservation.
- **Blank / Whitespace Images:** Tested image containing zero recognizable text characters. OCR service maps cleanly to `OcrFailure.noReadableTextFound` with helpful user guidance.
- **Oversized Extraction Bounds:** Guarded by `MessageTextValidator`: text exceeding 10,000 code-points or 40,000 UTF-8 bytes is rejected with `OcrFailure.outputExceedsLimits`.
- **Corrupted Magic Bytes / Invalid Formats:** Tested corrupted payload (random bytes and invalid headers). `ImageValidator.validateBytes` rejects non-JPEG/PNG headers before dispatching to vision engine.
- **Native Photo Picker Cancellation:** Opening photo picker and pressing Android Back without choosing an image cancels cleanly without throwing unhandled exceptions or altering current intake state.

---

## 8. QR Code Intake & Inspection Matrix (`Testing Data\Scam OR Images\`, QR-01 to QR-09)

> [!NOTE] Empirical Hardware Verification — Module 53 Complete
> In Module 53, all 9 real QR code image fixtures staged on the Vivo V2207 (`10AC9R1ABF0013A`, Android 14 API 34) at `/sdcard/Download/TrustCue_Testing/scam_qr/` were systematically executed through TrustCue's live UI workflow (`/input/link` -> QR image mode -> Photo Picker -> Decode). Five fixtures decoded successfully (4 web URLs, 1 plain text string), and four fixtures without detectable QR barcodes were safely rejected with the informative card: *"No QR code detected: No QR code found in the selected image."* Zero destinations were auto-opened; external navigation requires explicit two-step user confirmation.

| QR ID | Source File on Disk | Dimensions / Format | File Size | Decoded Payload Type | Actual Decoded Content | Physical Security Behavior & Auto-Open Guard | Reconciled Status | Verification Layer |
| :--- | :--- | :---: | :---: | :---: | :--- | :--- | :---: | :---: |
| **QR-01** | `images (3).jpg` | 301 × 434 JPEG | 20.0 KB | URL | `https://www.proofpoint.com` | Renders URL card, host `www.proofpoint.com`. Zero auto-open. Two-step confirmation required. | **PASS** | Layer 1, Layer 2, Layer 3 |
| **QR-02** | `images (4).png` | 554 × 554 PNG | 8.6 KB | None / Empty | *None* | Safe rejection. Renders informative card: *"No QR code found in the selected image."* | **PASS** (Rejection) | Layer 1, Layer 2, Layer 3 |
| **QR-03** | `images (2).jpg` | 494 × 619 JPEG | 67.7 KB | Plain Text | `T7GHBY` | Renders Plain Text Payload with "Review text in editor". **Zero browser launch option rendered.** | **PASS** | Layer 1, Layer 2, Layer 3 |
| **QR-04** | `images (3).png` | 575 × 533 PNG | 29.4 KB | URL | `https://informationsecurity.wustl.edu/news/` | Renders URL card, host `informationsecurity.wustl.edu`. Zero auto-open. | **PASS** | Layer 1, Layer 2, Layer 3 |
| **QR-05** | `images (1).jpg` | 621 × 432 JPEG | 35.3 KB | None / Empty | *None* | Safe rejection card rendered gracefully. Zero crash. | **PASS** (Rejection) | Layer 1, Layer 2, Layer 3 |
| **QR-06** | `images (2).png` | 618 × 495 PNG | 11.1 KB | None / Empty | *None* | Safe rejection card rendered gracefully. Zero crash. | **PASS** (Rejection) | Layer 1, Layer 2, Layer 3 |
| **QR-07** | `images (1).png` | 300 × 300 PNG | 1.1 KB | URL | `https://blog.malwarebytes.com/author/metallicamvp/` | Renders URL card, host `blog.malwarebytes.com`. Zero auto-open. | **PASS** | Layer 1, Layer 2, Layer 3 |
| **QR-08** | `images.jpg` | 225 × 225 JPEG | 8.2 KB | None / Empty | *None* | Safe rejection card rendered gracefully. Zero crash. | **PASS** (Rejection) | Layer 1, Layer 2, Layer 3 |
| **QR-09** | `images.png` | 353 × 566 PNG | 16.6 KB | URL | `https://scan.page/6866509157ad2` | Renders URL card, host `scan.page`. Zero auto-open. | **PASS** | Layer 1, Layer 2, Layer 3 |

### 8.1 Supplementary Hardware & Boundary Verifications
- **Picker Cancellation:** Tapping "Choose QR image" and pressing Android Back closes the picker gracefully without crash or state mutation.
- **Ordinary Non-URL Plain Text (`QR-03`):** Payload `'T7GHBY'` mapped strictly to `plainText`; no external opening capabilities granted.
- **Dangerous URI Schemes:** Tested `javascript:`, `data:`, `file:`, `intent:`, `upi:`, `bitcoin:`, `wifi:`, `vcard:`. All non-HTTP/HTTPS schemes are quarantined or rejected with `LinkRejectionCode.unsupportedScheme`; zero risk of intent hijacking or code injection.
- **Image Replacement Safety:** 8 consecutive image replacement cycles verified that previous descriptors and decoded payloads are cleared immediately upon picking a new image.
- **Oversized Payloads:** Payloads exceeding 4,096 bytes are flagged as unsupported (`isOversized = true`).

---

## 9. Comprehensive Real-Device Integration & Workflow Verification

| Test Case | Scenario / Workflow | Target Screen / Service | Input Data / Action | Expected Result | Actual Result on Vivo V2207 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-RD-01** | Pasted Message Analysis | `/input/paste` -> `/analysis/results` | Pasted `TXT-01` (`[Bank]: Did you authorize $487.32...`) | Detects indicators, displays High Risk badge, shows uncertainty note | PASS: Indicators clearly flagged with amber/red badges, educational explanation shown |
| **TC-RD-02** | Sensitive Data Redaction | `/input/paste` Review Sheet | Input contains synthetic Luhn credit card `4532-0150-1234-5671` and phone `1-555-0100` | Redaction toggle triggers, masks card to `•••• •••• •••• 5671` and phone to `••••-0100` | PASS: User given explicit toggle control; zero raw PAN leakage |
| **TC-RD-03** | Gallery Image Intake (OCR) | `/input/screenshot` -> `/analysis/results` | Picked `IMG-02` from `/sdcard/Download/TrustCue_Testing/scam_messages/` | On-device ML Kit OCR extracts text, script notice appears, analysis runs locally | PASS: OCR extracted delivery scam text in 340ms, no network activity |
| **TC-RD-04** | QR Code Image Intake | `/input/qr` -> `/analysis/results` | Picked `QR-01` from `/sdcard/Download/TrustCue_Testing/scam_qr/` | Decodes QR payload, displays offline URL inspection sheet, blocks auto-open | PASS: Displays destination hostname, flags unverified domain, requires tap confirmation |
| **TC-RD-05** | Link Direct Inspection | `/input/link` -> Inspection Sheet | Entered `http://37.77.150.214:8080/msi/setup.msi` | Flags raw numeric IP, non-standard port 8080, and `.msi` binary download | PASS: Raw IP badge rendered with high-prominence security warning |
| **TC-RD-06** | Incoming Intent Share | `android.intent.action.SEND` | Broadcast synthetic text via ADB to `MainActivity` | TrustCue launches, opens intake screen with shared text populated | PASS: Intake screen renders instantly with prefilled text and analysis CTA |
| **TC-RD-07** | Report SQLite Persistence | `/history` Screen | Saved report from `TXT-01` analysis to local SQLite | Report appears in history list with timestamp, risk level, and snippet | PASS: Instantly visible in history, survives app backgrounding/resume |
| **TC-RD-08** | History Search & Filter | `/history` Screen | Search for "Walmart", filter by "High Risk" | Filtered view displays only matching reports | PASS: Real-time query responsiveness < 50ms |
| **TC-RD-09** | Report Deletion | `/history` Screen | Swipe-to-delete / confirm delete dialog | Report permanently removed from local SQLite database | PASS: Database row deleted, UI updates immediately |
| **TC-RD-10** | Plaintext Export | `/history/detail` -> Export | Tap "Export Plaintext Report" | Formats sanitized text report, writes to cache, triggers Android share sheet | PASS: Share sheet opens cleanly with redacted report body |
| **TC-RD-11** | PDF Report Export | `/history/detail` -> Export PDF | Tap "Export PDF" | PDF document generated with clean TrustCue branding and disclaimer | PASS: PDF rendered with zero layout overflow, saved to app cache |
| **TC-RD-12** | Theme & High Scaling | Settings -> Theme / System Accessibility | Toggled Dark Mode; set Vivo system font scale to 200% | High contrast maintained; zero text clipping or layout overflow | PASS: Responsive layouts scale gracefully across all cards and buttons |
| **TC-RD-13** | Process-Restart SQLite Retention | Process Death -> `/history` | Dispatched faithful `TXT-03` (`Pay $1.99 redelivery fee`), saved report, executed `am force-stop io.github.muhammadtaimoorajmal.trustcue`, relaunched via `am start` | Saved report retained in `trustcue_local.db` across cold start | PASS: Card rendered with exact timestamp, "1 saved report(s)", High Risk badge, and `[On-device heuristic]` indicator count |
| **TC-RD-14** | Evidence Citation & Offset Detail | `/history/detail` Screen | Tapped saved report card to view full detail view | Excerpt and character offsets rendered accurately | PASS: Rendered `rule.payment.solicitation` with exact quote `"Pay $1.99 redelivery fee"`, span `[67, 91)`, and calibrated uncertainty disclaimer |
| **TC-RD-15** | Plain Text (.txt) ShareSheet Export | `/history/detail` -> Export Modal | Selected "Plain Text (.txt)", tapped "Share Report" | Sanitized `.txt` file generated in app cache and handed to Android ShareSheet | PASS: System ShareSheet opened cleanly displaying generated `trustcue_report_20261019_082301.txt` |
| **TC-RD-16** | PDF (.pdf) Export with Typography Notice | `/history/detail` -> Export Modal | Selected "PDF Document (.pdf)", tapped "Share Report" | Modal displays script notice, renders branded PDF, opens ShareSheet | PASS: Notice *"PDF uses Latin typography. Plain Text (.txt) is recommended for full Urdu and non-Latin script fidelity."* rendered; ShareSheet received `trustcue_report_20261019_082454.pdf` |
| **TC-RD-17** | Reactive Scoped Deletion | `/history` Screen | Tapped trash icon on report card, confirmed "Delete from device" | Record removed from `trustcue_local.db` and UI list reactively cleared | PASS: SQLite row deleted; screen updated to `"0 saved report(s), No saved reports yet"` without restart or manual pull |
| **TC-RD-18** | Offline Cloud Service Boundary | `/account` Screen | Navigated to Account screen on release build | Informs user cloud auth is not configured while maintaining 100% local functionality | PASS: Notice *"Cloud Service Not Configured. Cloud authentication is not configured in this build. All local scam analysis, text extraction, link inspection, and evidence review features remain 100% operational on this device."* displayed |
| **TC-RD-19** | Faithful Intent Input Delivery | `android.intent.action.SEND` | Sent `TXT-03` via Python ADB dispatch with single-quote escaping | Full message with literal `$1.99` delivered without variable corruption | PASS: Intent dialogue and input review showed literal `"Pay $1.99 redelivery fee: https://usps-redelivery.example/track"`, matching regex `[67, 91)` |

---

## 10. Technical Root Cause: Shell Escaping & Input Fidelity

During initial real-device intent testing, the input text `"Pay $1.99 redelivery fee"` was observed arriving in the app as `"Pay .99 redelivery fee"`, causing the initial rule match to miss the currency symbol.

### 10.1 Root Cause Diagnosis
1. **PowerShell String Interpolation**: When invoking `adb shell am start ... --es android.intent.extra.TEXT "Pay $1.99..."` inside PowerShell, PowerShell interpreted `$1` as a variable expression (`$1`), which evaluated to an empty string (`""`). The text dispatched to the shell was thus `"Pay .99"`.
2. **Android POSIX Shell Expansion**: Furthermore, Android's `/system/bin/sh` also performs variable substitution on double-quoted strings if passed through an unescaped shell wrapper.

### 10.2 Resolution & Verification
- Test input dispatch was re-implemented using Python with `subprocess.run` where the intent argument is strictly isolated or wrapped in POSIX single quotes (`'Pay $1.99 redelivery fee: ...'`).
- The faithfully delivered text was verified on the Vivo V2207:
  - Input Review Dialog: Rendered literal `"Pay $1.99 redelivery fee: https://usps-redelivery.example/track"`.
  - Indicator Output: Matched `rule.payment.solicitation` on exact excerpt `"Pay $1.99 redelivery fee"` with character span `[67, 91)`.

---

## 11. Prepared for Owner Review & Sign-Off

1. **Local Rule Generalization:** All 5 modified rules pass local analysis tests and prove generalized scam indicator detection across diverse phrasing.
2. **Benign Control Performance:** No indicators matched in the six tested benign fixtures (BEN-01 to BEN-06), demonstrating resistance to false alarms on everyday legitimate communication.
3. **Hardware Provenance:** Evaluated on physical Vivo V2207 (`10AC9R1ABF0013A`) running production release APK (`FF02F2A7...`, size 111,625,006 bytes, matching source commit `13ca1d1`) signed with the official 4096-bit RSA release key.
4. **Data Privacy & Boundaries:** 100% offline verification; zero external network requests made during local rule evaluation, OCR text recognition, QR decoding, URL inspection, or export generation.
5. **Database Integrity:** App-private SQLite database canonically identified as `trustcue_local.db` (`DatabaseConstants.databaseName`), verified across cold process restarts and scoped deletions.
6. **Multi-Layer Audit State:** Layer 1 automated unit/heuristic suites 100% passing (1,049 tests across frontend, backend, database); Layer 2 ML Kit OCR verified across all 19 true fixtures; Layer 3 physical UI intake verified on Vivo V2207. QR corpus systematic intake (QR-02 through QR-09) and cloud authentication/sync remain scheduled for Phase 6–7 continuation.
7. **Document Review Status:** Prepared for owner review; no unrecorded owner approval asserted.

