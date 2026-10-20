# TrustCue Demonstration Quick Reference (Classroom Cheat Sheet)

**Student:** Muhammad Taimoor Ajmal (SAP ID: 63461)  
**Course:** CS3643 — Mobile Application Development (BSCS 5-1, Fall 2026)  
**Instructor:** Mr. Muhammad Shariq Hasnain  
**Presentation Date:** Wednesday, 21 October 2026  
**Use Case:** Keep this single document visible on your laptop screen during your demonstration and viva.

---

## 1. Fast Facts & Key Metrics (Memorize or Reference)

| Metric / Fact | Value to State | Technical Location |
|---|---|---|
| **Total Automated Tests** | **1,136 tests** (100% passing across all 3 tiers) | 981 Flutter + 142 Backend pytest + 13 Database SQL |
| **Mobile Client Suite** | **981 tests** (0 failures, 0 skipped) | `flutter test --no-pub` |
| **Static Code Analyzer** | **0 issues found** (100% clean) | `flutter analyze --no-pub` |
| **Local Indicator Rules** | **10 pure-Dart rule families** | `lib/features/analysis/domain/rules/` |
| **Local Database** | `trustcue_local.db` (SQLite in Android app sandbox) | `lib/core/constants/database_constants.dart` |
| **Token Storage** | Android KeyStore hardware-backed AES-GCM | `flutter_secure_storage` (`SecureLocalStorage`) |
| **Text Input Bounds** | 10,000 Unicode runes / 40,000 UTF-8 bytes | `MessageTextValidator` |
| **Release Signing** | 4096-bit RSA keystore (APK Scheme v2 valid) | `android/key.properties` & `app-release.apk` |
| **Installed Release APK** | SHA-256: `FF02F2A79A4D1755EA1CF354BAB434658397DAAE760E7736622E90CBB16D006D` | Vivo V2207 (Android 14 API 34) |
| **Live Backend API** | FastAPI 0.115 on Render Cloud | `https://trustcue-backend.onrender.com` |
| **Live Database** | PostgreSQL 16 on Supabase (RLS enforced) | `https://yzqkmoqqvnhfmmrayfko.supabase.co` |
| **Cloud AI Provider** | Groq Cloud LPUs (`llama-3.3-70b-versatile`) | Zero data retention for model training |
| **Git Governance** | Exactly 4 branches (`main`, `frontend`, `backend`, `database`) | `main` locked at `a785db8` |

---

## 2. Timed Demonstration Agenda (10–12 Minutes)

```
00:00 - 01:00  [1 min]   Elevator Pitch & Real-World Problem (Social engineering in Pakistan)
01:00 - 02:00  [1 min]   App Launch & Home Dashboard Tour (Branding, clean UI, 3 input cards)
02:00 - 04:30  [2.5 min] Suspicious Message Demo ($1.99 Delivery Scam): Enter -> Review -> Local Rules -> Evidence Trail
04:30 - 05:45  [1.15 min] Benign Message Demo (Family pickup): Calm no-match state & honest limitation notice
05:45 - 07:15  [1.5 min] Safe Guided Practice & User Guide (Offline accordion, practice without internet)
07:15 - 08:45  [1.5 min] Link Inspector & Dangerous Scheme Defense (javascript: rejection, IP host, 2-step open)
08:45 - 10:00  [1.25 min] Local SQLite History, Search, Export (PDF/TXT) & Privacy Center
10:00 - 11:30  [1.5 min] Architecture Overview: Multi-tier separation, SQLite vs Supabase, cloud boundaries
11:30 - 12:00  [30 sec]  Conclusion, current status (Module 50 in progress), handover to viva Q&A
```

### Shortened 5-Minute Lightning Version
* **00:00–00:45:** 30-second problem statement & local-first philosophy.
* **00:45–02:15:** Suspicious $1.99 message: Input -> Review -> Evidence quote.
* **02:15–03:15:** Benign message: Honest no-match result.
* **03:15–04:15:** In-app User Guide or Link Inspector with dangerous scheme defense.
* **04:15–05:00:** Tech stack summary (Flutter + FastAPI + Supabase + 1,136 tests) and closing.

---

## 3. Click-and-Speak Action Cue Cards

### Cue Card 1: The 30-Second Elevator Pitch
* **Action:** Stand straight, phone held in hand, app showing the Home Screen.
* **Say Aloud:**
  > *"Respected Sir and classmates: TrustCue is an offline-first Android application designed to help people evaluate suspicious digital messages, screenshots, and links before falling victim to fraud. Unlike black-box tools that invent fake risk percentages, TrustCue uses deterministic on-device heuristics to ground every warning in verbatim evidence quotes. Core analysis works 100% offline without an account, while optional cloud AI and backup require explicit user consent and authentication."*

### Cue Card 2: Suspicious Message ($1.99 USPS Scam)
* **Action:**
  1. From Home, tap **"Check a message"**.
  2. Paste from `DEMO_INPUTS.txt` (Fixture 1): `USPS: Package USPS-928172 is held due to unpaid fee ($1.99)...`
  3. Tap **"Prepare text"** -> Shows Privacy Review screen.
  4. Tap **"Confirm reviewed text"** -> Tap **"Analyze on this device"**.
* **Say Aloud:**
  > *"Notice what happened: When I tapped 'Prepare text', TrustCue created an immutable text snapshot. No data left my phone. On analysis, the local engine fired the PaymentRequestRule, highlighted the exact quote 'Pay $1.99 redelivery fee', and provided safe verification steps. Notice the literal dollar sign is preserved intact."*
* **Point To on Screen:**
  - Red indicator badge: **"Requests for payment"**.
  - Highlighted excerpt: `"Pay $1.99 redelivery fee"`.
  - Next Actions card: *"Contact courier directly via official website or app."*

### Cue Card 3: Benign Message (Calm No-Match)
* **Action:**
  1. Tap back to Home -> Tap **"Check a message"**.
  2. Paste from `DEMO_INPUTS.txt` (Fixture 3): `Hi Mom, please bring groceries home tonight. Love you.`
  3. Tap **"Prepare text"** -> **"Confirm reviewed text"** -> **"Analyze on this device"**.
* **Say Aloud:**
  > *"When we analyze a completely ordinary message, TrustCue renders a calm blue 'No indicators detected' card. But crucially, look at the disclaimer: We do NOT state the message is '100% safe'. An absence of indicators only means it matched none of our 10 local heuristic rules. This prevents dangerous false sense of security."*
* **Point To on Screen:**
  - Calm status headline: **"No indicators detected"**.
  - Honest disclaimer card: *"This result is based on local checks. It does not certify the message is safe."*

### Cue Card 4: Safe Guided Practice & User Guide
* **Action:**
  1. From Home, tap overflow menu (three dots) -> Tap **"User Guide"**.
  2. Tap Topic 1 to show accordion expansion.
  3. Scroll to **"Safe Guided Practice"** -> Tap **"Urgent Account Suspension Threat"**.
  4. Tap **"Confirm reviewed text"** -> **"Analyze on this device"**.
* **Say Aloud:**
  > *"First-time users don't need technical knowledge. The built-in User Guide operates completely offline with 6 practical topics. With Safe Guided Practice, users can test synthetic scam examples right inside the app without risking their personal data or saving unwanted history."*
* **Point To on Screen:**
  - Topic accordion smoothly expanding.
  - Three detected warning signs: Urgency, Account Threat, Credential Request.

### Cue Card 5: Link Inspector & Dangerous Scheme Defense
* **Action:**
  1. Return to Home -> Tap **"Inspect a link"**.
  2. Paste: `http://37.77.150.214:8080/msi/setup_cf4cb3a3.msi`.
  3. Tap **"Inspect Link"** -> Point out IP, custom port, and HTTP badges.
  4. Paste: `javascript:alert('Safety Check')`.
  5. Tap **"Inspect Link"** -> Point out red rejection banner and disabled launch button.
* **Say Aloud:**
  > *"Our Link Inspector analyzes URLs structurally without browsing to them. It flags unencrypted HTTP, numerical IP hosts, and non-standard ports like 8080. If an attacker passes a dangerous javascript: or file: scheme, TrustCue quarantines it and disables external launch completely."*

### Cue Card 6: Local History, Search & PDF Export
* **Action:**
  1. From Results, tap **"Save report to device"**.
  2. Navigate to **History** (`/history`).
  3. Type `USPS` into the search bar -> List filters instantly via local SQLite query.
  4. Open report -> Tap **"Export"** -> Point out sanitized Plain Text and PDF export options.
* **Say Aloud:**
  > *"Reports are saved in an app-private SQLite database named trustcue_local.db. The search query filters locally with debouncing. When exporting to PDF or plain text, all sensitive payment cards remain masked."*

---

## 4. Emergency Contingency Plan (When Things Go Wrong)

| Emergency Situation | Immediate Action | Spoken Pivot for Class |
|---|---|---|
| **Phone Screen Cast / Projector Fails** | Hold phone physically; open VS Code code tour on laptop screen. | *"While we adjust the projector cable, let me show you the exact code implementation of the rule engine in Dart."* |
| **Phone Screen Goes Black / Locks** | Unlock with fingerprint; display timeout is set to 10 minutes. | Keep phone awake with occasional screen touches. |
| **Campus Wi-Fi Drops / Disconnects** | **Nothing breaks!** All core features are 100% offline. | *"This actually demonstrates our core design: TrustCue is local-first. We don't need Wi-Fi for analysis, OCR, or local reports."* |
| **Render Cloud Backend is Asleep** | Explain free-tier spin-up (~50 seconds) or skip to local code tour. | *"Render free-tier instances sleep after 15 minutes of inactivity. While the container spins up, let's inspect the OpenAPI contract."* |
| **Accidental Text Typo in Input** | Tap "Clear text" -> Confirm modal -> Re-paste from `DEMO_INPUTS.txt`. | *"Notice the safety dialog preventing accidental deletion of user drafts."* |

---

## 5. Top 10 Rapid-Fire Viva Answers (Short & Direct)

1. **Why is TrustCue 'Local-First'?**
   * *"Because sending a user's private messages or screenshots to a cloud server without consent violates privacy. Local heuristics run instantly without internet, cost zero server fees, and ensure the app works in areas with poor connectivity."*

2. **Is your local engine real AI or machine learning?**
   * *"No, and we are honest about that. The local engine uses deterministic heuristic rules written in pure Dart. It matches specific scam indicators like artificial urgency, payment demands, and credential requests. Machine learning is only used in Google ML Kit for on-device OCR, and in the optional cloud LLM."*

3. **Did you train your own AI model?**
   * *"No. We integrate a hosted enterprise LLM — Groq's Llama-3.3-70b-versatile — through our protected FastAPI backend. We authored the system prompts, JSON schemas, XML boundary isolation, and a custom evidence-grounding engine that verifies every quote byte-for-byte."*

4. **What is 'Evidence Grounding'?**
   * *"Evidence grounding is our algorithm that verifies that every quote cited by the AI model exists verbatim as an exact substring in the user's source text. If the AI hallucinates a quote, our backend validator detects and rejects it before sending it to the phone."*

5. **Does 'No indicators detected' mean the message is completely safe?**
   * *"No, absolutely not. We display an explicit disclaimer that no indicators detected only means the message matched none of our 10 heuristic rules. It could be a new scam variant. We never give a false guarantee of 100% safety."*

6. **What is stored in the local SQLite database vs. the cloud?**
   * *"The local SQLite database (`trustcue_local.db`) stores user-saved reports with their text and evidence spans inside the private app sandbox. The cloud database (`synced_reports`) stores only high-level metadata — counts, categories, and timestamps — never raw message text or evidence quotes."*

7. **How does Row Level Security (RLS) protect cloud data?**
   * *"PostgreSQL Row Level Security enforces security at the database engine level. Every table has policies with `USING (auth.uid() = user_id)`. Even if an attacker knew another user's report UUID, the database kernel refuses to return or update the row."*

8. **Why are there four Git branches instead of merging to main?**
   * *"We follow a strict architectural ownership model: `frontend` owns mobile, `backend` owns the API, and `database` owns migrations. The `main` branch remains locked at its initial baseline (`a785db8`) until formal academic evaluation and owner approval. This prevents premature unverified merges."*

9. **What is the difference between an APK and an AAB?**
   * *"An AAB (Android App Bundle) is an publishing format compiled for the Google Play Store, which splits binaries per device architecture. An APK (Android Package) is a standalone binary that can be directly installed on a physical phone via ADB or file transfer."*

10. **How did you use AI coding tools in this project?**
    * *"I used AI assistance as an advanced pair programmer to scaffold tests, explore regex patterns, and help write documentation. However, every architectural decision, security constraint, hardware test on my Vivo phone, and line of code was verified, debugged, and understood by me."*
