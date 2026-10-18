# TrustCue Google Play Store Listing Specification & Assets (Module 49)

## Executive Summary
This document provides the complete, policy-compliant store listing copy, metadata, asset specifications, and regulatory disclosures for **TrustCue** on the **Google Play Store**. All descriptions, feature claims, graphic assets, and character counts strictly adhere to current Google Play Developer Program Policies (audited October 18, 2026).

---

## 1. Regulatory Context & Policy Sources

| Requirement / Domain | Policy Source & Authority | Official Reference URL | Access Date |
|---|---|---|---|
| **Store Listing & Graphic Assets** | Google Play Console Help: Graphic assets, screenshots, and video | `https://support.google.com/googleplay/android-developer/answer/9866151` | October 18, 2026 |
| **Metadata Policy** | Developer Policy Center: Metadata & Promotional Claims | `https://play.google.com/about/metadata/` | October 18, 2026 |
| **Data Safety Section** | Google Play Console Help: Provide information for Google Play's Data safety section | `https://support.google.com/googleplay/android-developer/answer/10787469` | October 18, 2026 |
| **User Data & Account Deletion** | Developer Policy Center: User Data & Delete Account URL Policy | `https://support.google.com/googleplay/android-developer/answer/13327111` | October 18, 2026 |
| **App Access Requirements** | Google Play Console Help: Prepare your app for review (App access credentials) | `https://support.google.com/googleplay/android-developer/answer/9859455` | October 18, 2026 |
| **Testing Tracks Policy** | Google Play Console Help: Set up an open, closed, or internal test | `https://support.google.com/googleplay/android-developer/answer/9845334` | October 18, 2026 |

---

## 2. Store Listing Metadata & Copy

### 2.1 Application Title (App Name)
- **Primary Title:** `TrustCue: Scam Indicators` (26 / 30 characters)
- **Alternative Title:** `TrustCue` (8 / 30 characters)
- **Policy Compliance:** Does not include promotional superlatives ("#1", "Best", "Top"), price terms ("Free"), or call-to-action commands ("Download").

### 2.2 Short Description
- **Copy:** `Understand suspicious messages and links with privacy-first on-device checks.`
- **Character Count:** 78 / 80 characters.
- **Policy Compliance:** Accurately summarizes core functionality without deceptive claims or keyword stuffing.

### 2.3 Full Description
- **Character Count:** 2,940 / 4,000 characters.
- **Full Text:**

```text
TrustCue helps you understand suspicious digital communications by identifying common social engineering patterns, manipulative language, and structural link anomalies—with privacy at the foundation.

HONEST LIMITATIONS & NON-VERDICT PRINCIPLES
TrustCue provides educational indicators and evidence highlights, not absolute verdicts. The app does not guarantee safety, does not prove that a message is authentic or fraudulent, and never fabricates scam-probability percentages. Technology cannot replace independent verification: always verify sensitive requests directly with the sender through an official, independently confirmed channel before taking action.

CORE FEATURES

1. Multiple Local Input Channels
• Message Text: Copy and paste suspicious SMS, email, or chat messages.
• Screenshot OCR: Extract text locally on your device using on-device optical character recognition (Google ML Kit Latin models). Original images are processed in volatile memory and never uploaded.
• Link & QR Inspection: Review destination domain structures, Punycode representations, IP host formats, and multiple subdomains before opening them in a browser.

2. On-Device Sensitive Data Review & Redaction
Before running any analysis, review the message in the interactive Review screen. TrustCue automatically flags candidate sensitive data—such as phone numbers, email addresses, and verification codes—allowing you to mask or redact them locally before proceeding.

3. Deterministic On-Device Rule Engine
Evaluate text against 10 transparent scam-indicator categories:
• Urgency and artificial time pressure
• Requests for passwords or credentials
• Demands for one-time verification codes
• Demands for unusual payment methods
• Threats of account suspension or penalties
• Unsolicited job, reward, or investment promises
• Structural anomalies in embedded links and URLs
Every detected indicator produces an Evidence Trail displaying the exact supporting text excerpt and offset location.

4. Optional, Consented Cloud AI Assistance
When enabled, registered users can request a secondary linguistic evaluation powered by Groq Cloud models. Remote processing requires explicit affirmative consent for each request. Only your reviewed, redacted text is transmitted over secure TLS; screenshots, images, device identifiers, and account credentials are never sent to the AI provider.

5. Privacy-First Local History & Structured Export
• Sandboxed Local Storage: Saved reports are stored exclusively on your device in an encrypted app-private SQLite database.
• Privacy-Bounded Export: Export findings into clean Plain Text (.txt) or paginated PDF documents with strict privacy controls—reviewed text and quotes are excluded by default unless explicitly included.
• Optional Account Sync: Cloud report synchronization is strictly opt-in and transmits metadata only (indicator categories, timestamps, and risk level). Message text, evidence quotes, and images are cryptographically and architecturally blocked from cloud sync.

PRIVACY BY DESIGN
• Guest mode is 100% functional: local intake, OCR, redaction, 10-rule analysis, evidence trails, and exports require no account or login.
• No location tracking, no advertising SDKs, and no background device fingerprinting.
• Permanent account and cloud data deletion available directly in-app and via external web request.
```

### 2.4 Store Categorization & Tags
- **Primary Category:** `Tools` (or `Productivity`)
- **Tags:**
  1. `Security & Privacy`
  2. `Productivity`
  3. `Text Scanner`
  4. `QR Scanner`
  5. `Utility`
- **Category Rationale:** TrustCue is an on-device utility and educational tool that assists users in reviewing digital text and destinations. Categorizing under "Tools" accurately reflects its utility nature while avoiding misclassification as an automated antivirus or carrier-level blocking service.

### 2.5 Release Notes (What's New)
- **Version:** `0.1.0` (versionCode `1`)
- **Language:** English (`en-US`)
- **Copy (under 500 characters):**
```text
Welcome to TrustCue v0.1.0!
• Local scam-indicator analysis across 10 transparent categories.
• On-device Latin text recognition (OCR) from screenshots.
• Link inspection and QR code destination decoding.
• Interactive sensitive data detection and local redaction.
• Evidence trail linking findings to exact excerpts.
• Privacy-first local SQLite report history and export (Text & PDF).
• Bilingual interface support (English and Urdu).
• Optional consented Groq Cloud AI analysis.
```

---

## 3. Compliant Graphic Assets Inventory

All graphic assets are generated and located in `docs/store_assets/`:

| Asset Name | Target Resolution | Format & Mode | File Path | Policy Compliance Check |
|---|---|---|---|---|
| **App Icon** | 512 x 512 px | 32-bit PNG (RGBA), max 1MB | `docs/store_assets/icon_512.png` | Full square, no artificial rounded corners or shadows; approved Deep Navy (`#0A2540`), Dark Teal (`#00695C`), Light Teal (`#4DB6AC`), Amber (`#FFB300`). |
| **Feature Graphic** | 1024 x 500 px | 24-bit PNG (RGB, no alpha), max 15MB | `docs/store_assets/feature_graphic_1024x500.png` | Centered branding within 800x400 safe zone; zero promotional terms ("#1", "Free", "Download now"). |
| **Screenshot 1: Dashboard** | 1080 x 1920 px | 24-bit PNG (RGB), 9:16 portrait | `docs/store_assets/screenshots/screen1_home_dashboard.png` | Captured from physical Vivo V2207 running release build. Shows input channels and honest indicator disclaimers. |
| **Screenshot 2: Review** | 1080 x 1920 px | 24-bit PNG (RGB), 9:16 portrait | `docs/store_assets/screenshots/screen2_privacy_review.png` | Captured from physical Vivo V2207. Shows on-device phone number redaction tile and synthetic message text. |
| **Screenshot 3: Evidence** | 1080 x 1920 px | 24-bit PNG (RGB), 9:16 portrait | `docs/store_assets/screenshots/screen3_analysis_results.png` | Captured from physical Vivo V2207. Shows 2 detected indicators and exact excerpt grounding. |
| **Screenshot 4: Export** | 1080 x 1920 px | 24-bit PNG (RGB), 9:16 portrait | `docs/store_assets/screenshots/screen4_evidence_export.png` | Captured from physical Vivo V2207. Shows privacy-reviewed export sheet with reviewed text excluded by default. |

---

## 4. Policy Compliance Verification Checklist

- [x] **No Unsupported Security Guarantees:** Descriptions explicitly state findings are educational indicators and not absolute proof of fraud or safety.
- [x] **No Fabricated Data or Testimonials:** Zero fictitious user quotes, fake ratings, or artificial percentage accuracy scores.
- [x] **Dimension & Aspect Ratio Conformance:** Screenshots conform to 1080 x 1920 (9:16 aspect ratio), meeting the 320px–3840px dimension limit and <= 2:1 ratio rules.
- [x] **Metadata Limits Enforced:** Title <= 30 chars, short description <= 80 chars, full description <= 4,000 chars.
- [x] **No Disallowed Promo Keywords in Assets:** Feature graphic and screenshots contain zero price, ranking, or download commands.

