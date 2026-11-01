# Module 56 Evidence Dossier: Extended Link & Scheme Inspection Corpus

- **Module ID:** MODULE 56
- **Feature Area:** URL Parsing, IP Detection, Scheme Guard, and Offline Link Structural Inspection (Feature F-09)
- **Baseline Git Checkpoint:** `bb51783` (CI Run #41315448216 Passed)
- **Target Repository & Branch:** `trustcue-mobile` on branch `frontend`
- **Authoritative Date:** November 1, 2026
- **Device Tested:** Vivo V2207 (`10AC9R1ABF0013A`, Android 14 API 34)
- **Installed Release APK SHA-256:** `3409B8B0913350BD317DE6D2A17F1AFA0CD0502E74A513FD0946F1F210AFE666` (112,223,333 bytes)

---

## 1. Executive Summary & Purpose

Module 56 executes a rigorous, multi-layered verification of TrustCue's offline link and URI scheme inspection engine (`UrlInspectionService` and `InputLinkController`). 

### Core Safety Principle
> [!IMPORTANT]
> **No warning signs found must never mean "verified safe."**
> TrustCue's URL inspection service evaluates structural syntax, RFC 3986 compliance, IP host patterns, user-controlled hosting platform indicators, and URL shortener markers **entirely offline on the user's device**. It is not a website reputation service, malware scanner, or domain ownership validator. Benign-looking structure never establishes that a destination is safe.

All 57 fixtures from `Testing Data/Links.txt` were systematically inventoried, audited, and verified against production inspection logic without forcing or altering the natural corpus count. In addition, 16 supplementary edge-case categories were implemented and verified through automated test suites (1,048/1,048 tests passing) and 8 representative interactive UI journeys executed live on the connected Vivo V2207 Android 14 device (including an explicit offline test with all cellular and Wi-Fi data severed).

---

## 2. Hardware and Client Environment

- **Model:** Vivo V2207 (V2027 / PD2207)
- **Device Serial:** `10AC9R1ABF0013A`
- **Android Version:** Android 14 (API Level 34)
- **Application Package:** `com.trustcue.app`
- **Release Build Provenance:**
  - Build Script: `frontend/scripts/build_release.ps1 -Install`
  - Artifact: `frontend/build/app/outputs/flutter-apk/app-release.apk`
  - File Size: `112,223,333` bytes (107.02 MB)
  - SHA-256 Checksum: `3409B8B0913350BD317DE6D2A17F1AFA0CD0502E74A513FD0946F1F210AFE666`
  - Signature: Signed with production 4096-bit RSA keystore, APK Signature Scheme v2 verified via `apksigner`.
- **Backend Service Baseline:** FastAPI hosted on Render (`https://trustcue-backend.onrender.com`), PostgreSQL on Supabase.

---

## 3. Security & Safety Invariants

During Module 56, the following strict client invariants were preserved and empirically tested:
1. **Zero Network Egress:** Inspection runs strictly offline. `UrlInspectionService` makes zero HTTP/HTTPS network calls, zero DNS lookups, and zero background telemetry transmissions.
2. **Zero Automatic Launch:** Entering, pasting, or inspecting a URL in TrustCue will never automatically dispatch an `Intent.ACTION_VIEW` or open a browser or WebView.
3. **Explicit Affirmative Confirmation:** Only valid, launchable web schemes (`http` and `https`) expose an external launch pathway. Launching requires explicit, conscious user confirmation via an alert dialog displaying the full destination URL.
4. **Dangerous Scheme Quarantine:** Actionable schemes that could trigger arbitrary native code execution or dialer actions (`javascript:`, `data:`, `file:`, `content:`, `intent:`, `tel:`, `sms:`, `mailto:`) are strictly rejected and quarantined as unlaunchable.
5. **Private IP Egress Mitigation:** Local and private IPv4/IPv6 ranges (e.g. `127.0.0.1`, `192.168.1.1`, `10.0.0.0/8`, `172.16.0.0/12`, `fe80::/10`, `::ffff:192.168.1.1`) are classified as local/private hosts and blocked from external launch to prevent local network scanning or SSRF-type attacks from the device.

---

## 4. Links.txt Corpus Inventory & Reconciliation

### Corpus Anatomy
- **Source File:** `Testing Data/Links.txt` (mirrored at `frontend/test/fixtures/data/Links.txt`).
- **Total Physical File Lines:** 116 lines.
  - Blank separator lines: 57 lines.
  - Informational category header lines: 2 lines (Line 61: `Malware & Exploit URLs`, Line 62: `-----------------------`).
  - Raw URL fixture entries: **Exactly 57 entries** (`URL-001` through `URL-057`).
- **Parenthetical Annotations:** 15 entries contain contextual threat annotations (e.g., `(Tagged as Amadey)`, `(A fake Amazon page)`). These are parsed and separated cleanly from the URL destination.

### Complete 57-Fixture Acceptance Table

﻿| ID | Raw URL | Scheme | Host | Port | Observations / Findings | Status |
| :--- | :--- | :---: | :--- | :---: | :--- | :---: |
| **URL-001** | `https://facebook-verification-system4.blogspot.com/` | `https` | `facebook-verification-system4.blogspot.com` | None | Destination is hosted on a public cloud or hosting platform ("blogspot.com") under a user-controlled subdomain. | **PASS** |
| **URL-002** | `https://www.online-facebook-privacy.blogspot.com/` | `https` | `www.online-facebook-privacy.blogspot.com` | None | Destination is hosted on a public cloud or hosting platform ("blogspot.com") under a user-controlled subdomain. | **PASS** |
| **URL-003** | `https://trust-wallet-login.vercel.app/staking` | `https` | `trust-wallet-login.vercel.app` | None | Destination is hosted on a public cloud or hosting platform ("vercel.app") under a user-controlled subdomain. | **PASS** |
| **URL-004** | `https://ledger-live-cloud-deesktop.pages.dev/` | `https` | `ledger-live-cloud-deesktop.pages.dev` | None | Destination is hosted on a public cloud or hosting platform ("pages.dev") under a user-controlled subdomain. | **PASS** |
| **URL-005** | `http://connect-ledger-login.wasmer.app/` | `http` | `connect-ledger-login.wasmer.app` | None | Destination is hosted on a public cloud or hosting platform ("wasmer.app") under a user-controlled subdomain.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-006** | `https://www.paypal-transactions.sbs/shop/checkout.html` | `https` | `www.paypal-transactions.sbs` | None | Standard Web Structure | **PASS** |
| **URL-007** | `https://paypal-password.blogspot.com/` | `https` | `paypal-password.blogspot.com` | None | Destination is hosted on a public cloud or hosting platform ("blogspot.com") under a user-controlled subdomain. | **PASS** |
| **URL-008** | `https://www.roblox.com.bn/users/619170392353/profile` | `https` | `www.roblox.com.bn` | None | Hostname contains an embedded domain pattern ("roblox.com") within its subdomains; the actual destination root is "com.bn". | **PASS** |
| **URL-009** | `https://www.roblox.com.bn/games/76111710810728/NEW-Steal-A-Zoo?privateServerLinkCode=...` | `https` | `www.roblox.com.bn` | None | Hostname contains an embedded domain pattern ("roblox.com") within its subdomains; the actual destination root is "com.bn".; Destination contains 1 query parameter(s). | **PASS** |
| **URL-010** | `https://www.robiox.com.py/users/370132405543/profile` | `https` | `www.robiox.com.py` | None | **Corpus Note:** (Note the typo in "roblox"); Hostname contains an embedded domain pattern ("robiox.com") within its subdomains; the actual destination root is "com.py". | **PASS** |
| **URL-011** | `https://https--www--roblox.com/users/475726061/profile` | `https` | `https--www--roblox.com` | None | Standard Web Structure | **PASS** |
| **URL-012** | `https://www.instagram-users.blogspot.com/?m=1` | `https` | `www.instagram-users.blogspot.com` | None | Destination is hosted on a public cloud or hosting platform ("blogspot.com") under a user-controlled subdomain.; Destination contains 1 query parameter(s). | **PASS** |
| **URL-013** | `https://instagram-com-ig.github.io/instagram-com.github.io` | `https` | `instagram-com-ig.github.io` | None | Destination is hosted on a public cloud or hosting platform ("github.io") under a user-controlled subdomain. | **PASS** |
| **URL-014** | `https://www.loginmyfacebook.blogspot.com/` | `https` | `www.loginmyfacebook.blogspot.com` | None | Destination is hosted on a public cloud or hosting platform ("blogspot.com") under a user-controlled subdomain. | **PASS** |
| **URL-015** | `https://community-fb1.vercel.app/` | `https` | `community-fb1.vercel.app` | None | Destination is hosted on a public cloud or hosting platform ("vercel.app") under a user-controlled subdomain. | **PASS** |
| **URL-016** | `http://www.facebook-verification-system4.blogspot.com/` | `http` | `www.facebook-verification-system4.blogspot.com` | None | Destination is hosted on a public cloud or hosting platform ("blogspot.com") under a user-controlled subdomain.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-017** | `https://www.facebook--br.blogspot.com/` | `https` | `www.facebook--br.blogspot.com` | None | Destination is hosted on a public cloud or hosting platform ("blogspot.com") under a user-controlled subdomain. | **PASS** |
| **URL-018** | `https://facebooklogin1234.blogspot.com/` | `https` | `facebooklogin1234.blogspot.com` | None | Destination is hosted on a public cloud or hosting platform ("blogspot.com") under a user-controlled subdomain. | **PASS** |
| **URL-019** | `https://neda-facebook.blogspot.com/` | `https` | `neda-facebook.blogspot.com` | None | Destination is hosted on a public cloud or hosting platform ("blogspot.com") under a user-controlled subdomain. | **PASS** |
| **URL-020** | `https://www.jo-facebook.blogspot.com/` | `https` | `www.jo-facebook.blogspot.com` | None | Destination is hosted on a public cloud or hosting platform ("blogspot.com") under a user-controlled subdomain. | **PASS** |
| **URL-021** | `https://davidco564.github.io/r4w2ws2` | `https` | `davidco564.github.io` | None | Destination is hosted on a public cloud or hosting platform ("github.io") under a user-controlled subdomain. | **PASS** |
| **URL-022** | `https://officialgangwaranmol.github.io/amazone_clone/` | `https` | `officialgangwaranmol.github.io` | None | **Corpus Note:** (A fake Amazon page); Destination is hosted on a public cloud or hosting platform ("github.io") under a user-controlled subdomain. | **PASS** |
| **URL-023** | `https://manikandan-moto.github.io/netflixwebpage` | `https` | `manikandan-moto.github.io` | None | **Corpus Note:** (A fake Netflix page); Destination is hosted on a public cloud or hosting platform ("github.io") under a user-controlled subdomain. | **PASS** |
| **URL-024** | `http://uspssmartparcellocker.tech/` | `http` | `uspssmartparcellocker.tech` | None | Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-025** | `https://www.uspssmartpackagelockers.com/` | `https` | `www.uspssmartpackagelockers.com` | None | Standard Web Structure | **PASS** |
| **URL-026** | `http://vonovia-immobilien-house.com/` | `http` | `vonovia-immobilien-house.com` | None | Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-027** | `https://s4w.in/roblox-com-uk-users-8928613773-profile` | `https` | `s4w.in` | None | Destination uses a URL shortening or link redirection domain ("s4w.in"). The final destination cannot be determined offline without network redirection. | **PASS** |
| **URL-028** | `https://wells99.github.io/pageAlunos/` | `https` | `wells99.github.io` | None | Destination is hosted on a public cloud or hosting platform ("github.io") under a user-controlled subdomain. | **PASS** |
| **URL-029** | `https://f005.backblazeb2.com/b2api/v1/b2_download_file_by_id?fileId=...` | `https` | `f005.backblazeb2.com` | None | Destination contains 1 query parameter(s). | **PASS** |
| **URL-030** | `https://share.google/1CUx4XF0XRwYPB1HR` | `https` | `share.google` | None | **Corpus Note:** (A shortened URL, a common phishing tactic); Destination uses a URL shortening or link redirection domain ("share.google"). The final destination cannot be determined offline without network redirection. | **PASS** |
| **URL-031** | `http://37.77.150.214:8080/msi/setup_cf4cb3a3.msi` | `http` | `37.77.150.214` | 8080 | Destination uses a numerical IP address (37.77.150.214) instead of a registered domain name.; Destination connects to non-standard network port :8080.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-032** | `http://193.143.1.174/index.ps1` | `http` | `193.143.1.174` | None | Destination uses a numerical IP address (193.143.1.174) instead of a registered domain name.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-033** | `http://193.143.1.217/scheldt` | `http` | `193.143.1.217` | None | **Corpus Note:** (Tagged as ACRStealer); Destination uses a numerical IP address (193.143.1.217) instead of a registered domain name.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-034** | `http://193.143.1.16/g8hrS4f4vh/Plugins/cred.dll` | `http` | `193.143.1.16` | None | **Corpus Note:** (Tagged as Amadey); Destination uses a numerical IP address (193.143.1.16) instead of a registered domain name.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-035** | `http://193.143.1.16/g8hrS4f4vh/Plugins/vnc.exe` | `http` | `193.143.1.16` | None | **Corpus Note:** (Tagged as TinyNuke); Destination uses a numerical IP address (193.143.1.16) instead of a registered domain name.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-036** | `http://193.143.1.133/test/amnew.exe` | `http` | `193.143.1.133` | None | **Corpus Note:** (Tagged as Amadey); Destination uses a numerical IP address (193.143.1.133) instead of a registered domain name.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-037** | `http://193.143.1.117/hmips` | `http` | `193.143.1.117` | None | **Corpus Note:** (An ELF file, often for Linux/IoT devices); Destination uses a numerical IP address (193.143.1.117) instead of a registered domain name.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-038** | `http://193.143.1.32/tmips` | `http` | `193.143.1.32` | None | **Corpus Note:** (Tagged as Mirai botnet); Destination uses a numerical IP address (193.143.1.32) instead of a registered domain name.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-039** | `http://ets-cold.duckdns.org/powerpc.nn` | `http` | `ets-cold.duckdns.org` | None | **Corpus Note:** (Part of a Gorilla Botnet campaign); Destination is hosted on a public cloud or hosting platform ("duckdns.org") under a user-controlled subdomain.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-040** | `http://ets-cold.duckdns.org/arm.nn` | `http` | `ets-cold.duckdns.org` | None | Destination is hosted on a public cloud or hosting platform ("duckdns.org") under a user-controlled subdomain.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-041** | `http://ets-cold.duckdns.org/arm6.nn` | `http` | `ets-cold.duckdns.org` | None | Destination is hosted on a public cloud or hosting platform ("duckdns.org") under a user-controlled subdomain.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-042** | `http://ets-cold.duckdns.org/mipsel.nn` | `http` | `ets-cold.duckdns.org` | None | Destination is hosted on a public cloud or hosting platform ("duckdns.org") under a user-controlled subdomain.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-043** | `http://ets-cold.duckdns.org/arm7.nn` | `http` | `ets-cold.duckdns.org` | None | Destination is hosted on a public cloud or hosting platform ("duckdns.org") under a user-controlled subdomain.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-044** | `http://ets-cold.duckdns.org/m68k.nn` | `http` | `ets-cold.duckdns.org` | None | Destination is hosted on a public cloud or hosting platform ("duckdns.org") under a user-controlled subdomain.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-045** | `http://ets-cold.duckdns.org/sparc.nn` | `http` | `ets-cold.duckdns.org` | None | Destination is hosted on a public cloud or hosting platform ("duckdns.org") under a user-controlled subdomain.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-046** | `http://ets-cold.duckdns.org/arm5.nn` | `http` | `ets-cold.duckdns.org` | None | Destination is hosted on a public cloud or hosting platform ("duckdns.org") under a user-controlled subdomain.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-047** | `http://ets-cold.duckdns.org/x86_64.nn` | `http` | `ets-cold.duckdns.org` | None | Destination is hosted on a public cloud or hosting platform ("duckdns.org") under a user-controlled subdomain.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-048** | `http://ets-cold.duckdns.org/mips.nn` | `http` | `ets-cold.duckdns.org` | None | Destination is hosted on a public cloud or hosting platform ("duckdns.org") under a user-controlled subdomain.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-049** | `https://hardly-signatures-loc-surf.trycloudflare.com/download/WindowsUpdate.ps1` | `https` | `hardly-signatures-loc-surf.trycloudflare.com` | None | **Corpus Note:** (A malicious PowerShell script); Destination is hosted on a public cloud or hosting platform ("trycloudflare.com") under a user-controlled subdomain. | **PASS** |
| **URL-050** | `https://raw.githubusercontent.com/thuhangn562727-del/maqueo/raw/refs/heads/main/gaylo.exe` | `https` | `raw.githubusercontent.com` | None | Standard Web Structure | **PASS** |
| **URL-051** | `http://185.166.155.141:5001/irzfcxiywhew.exe` | `http` | `185.166.155.141` | 5001 | Destination uses a numerical IP address (185.166.155.141) instead of a registered domain name.; Destination connects to non-standard network port :5001.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-052** | `http://108.168.10.70:38308/i` | `http` | `108.168.10.70` | 38308 | Destination uses a numerical IP address (108.168.10.70) instead of a registered domain name.; Destination connects to non-standard network port :38308.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-053** | `http://163.142.86.141:43603/i` | `http` | `163.142.86.141` | 43603 | Destination uses a numerical IP address (163.142.86.141) instead of a registered domain name.; Destination connects to non-standard network port :43603.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-054** | `https://37.77.150.120/Bin/ScreenConnect.ClientSetup.exe` | `https` | `37.77.150.120` | None | **Corpus Note:** (A remote access tool); Destination uses a numerical IP address (37.77.150.120) instead of a registered domain name. | **PASS** |
| **URL-055** | `https://37.77.150.120/bin/support.client.exe` | `https` | `37.77.150.120` | None | Destination uses a numerical IP address (37.77.150.120) instead of a registered domain name. | **PASS** |
| **URL-056** | `http://193.143.1.186/cl-ncl-start` | `http` | `193.143.1.186` | None | **Corpus Note:** (A PowerShell script); Destination uses a numerical IP address (193.143.1.186) instead of a registered domain name.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |
| **URL-057** | `http://193.143.1.118/main_arm` | `http` | `193.143.1.118` | None | **Corpus Note:** (Tagged as Mirai); Destination uses a numerical IP address (193.143.1.118) instead of a registered domain name.; Uses unencrypted HTTP connection. Traffic sent to this site is not protected by TLS encryption. | **PASS** |


---

## 5. Supplementary Edge-Case & Boundary Matrix

To guarantee robust protection beyond the 57 static links in `Links.txt`, 16 supplementary edge cases were codified in `frontend/test/fixtures/extended_link_corpus_test.dart` and validated against the production engine:

| Category | Input Scenario | Tested Behavior & Production Result | Status |
| :--- | :--- | :--- | :---: |
| **1. Benign Counterexamples** | `https://example.com/`, `https://docs.flutter.dev/get-started` | Valid `https`, `isIpAddress: false`, `isPunycode: false`, 0 false-positive risk warnings. | **PASS** |
| **2. Case Normalization** | `HTTPS://EXAMPLE.COM/MixedCasePath?Param=Value` | Scheme normalized to `https`, host normalized to `example.com`, path and query casing preserved verbatim. | **PASS** |
| **3. Whitespace Handling** | `   https://example.com/clean   ` vs `https://example.com/bad path` | Surrounding whitespace trimmed safely; interior whitespace rejected as malformed. | **PASS** |
| **4. Missing Protocol Scheme** | `example.com`, `www.example.org`, `sub.domain.net/test` | Rejected with `LinkRejectionCode.missingScheme`; clear prompt requiring `https://`. | **PASS** |
| **5. User-Info Deception** | `https://paypal.com@evil.example/`, `http://admin:secret@legit.example` | Rejected with `LinkRejectionCode.containsUserInfo`; blocks credential harvesting and host masking. | **PASS** |
| **6. Literal @ in Path/Query** | `https://example.com/users/@handle`, `?email=support@example.com` | Valid `https`, `hasUserInfo: false`; permitted in RFC-compliant path/query segments. | **PASS** |
| **7. Domain Fronting / Subdomains** | `https://paypal.com.evil.example/login` | Valid, observed: *Hostname contains an embedded domain pattern ("paypal.com") within its subdomains; actual root is "evil.example".* | **PASS** |
| **8. IPv4 Public vs Private** | `http://93.184.216.34/` vs `http://192.168.1.1/` | Public IP accepted & flagged as numerical IP; RFC 1918 private IP rejected from external launch. | **PASS** |
| **9. IPv6 Public vs Private** | `http://[2001:db8::1]/` vs `http://[fe80::1]/`, `http://[::ffff:192.168.1.1]/` | Documentation IPv6 accepted & flagged; local/private/IPv4-mapped IPv6 rejected. | **PASS** |
| **10. Port Observations & Validity** | `:8443` vs `:80` / `:443` vs `:65536` | Non-standard port 8443 observed; standard 80/443 omitted from warnings; port 65536 rejected. | **PASS** |
| **11. Query & Redirect Keys** | `https://example.com/sso?target=https://destination.example/home` | 1 query parameter counted; destination redirection key observed. | **PASS** |
| **12. Percent-Encoding Integrity** | `https://example.com/%20%2F` vs `https://example.com/%zz` | Valid percent escapes preserved; invalid hexadecimal escape sequences rejected. | **PASS** |
| **13. Punycode vs Unicode** | `https://xn--e1afmkfd.xn--p1ai/` vs `https://россия.рф/` | ASCII Punycode (`xn--`) accepted & flagged; raw non-ASCII Unicode rejected with clear explanation. | **PASS** |
| **14. URL Shortener Hostnames** | `https://share.google/...`, `https://s4w.in/...`, `https://bit.ly/...` | Observed: *Destination uses a URL shortening or link redirection domain. Destination cannot be determined offline.* | **PASS** |
| **15. Dangerous Scheme Isolation** | `javascript:`, `data:`, `file:`, `content:`, `intent:`, `tel:`, `sms:`, `mailto:` | Strictly rejected with `LinkRejectionCode.unsupportedScheme`; zero external launch capability. | **PASS** |
| **16. Length Bounds & Special Chars** | `> 4096` bytes, control characters (``), zero-width, bidi, backslashes | Strict length cap enforced; invisible, bidi override, and backslash bypass attempts rejected. | **PASS** |

---

## 6. Physical Device Verification Log on Vivo V2207

The test harness script `scratch/execute_physical_m56_cases.py` executed 8 distinct test cases against the installed release build on the Vivo V2207. Each case cleared the input controller, pasted the test input, dismissed the Android soft keyboard, engaged `UrlInspectionService`, and captured high-resolution device screenshots and UI hierarchy dumps.

### Physical UI Test Case Summary

| Case # | Test Case Description | Raw Input Tested | Observed Device UI Elements & Results | Screen Artifact | Hierarchy Dump |
| :---: | :--- | :--- | :--- | :---: | :---: |
| **1** | Ordinary Benign HTTPS | `https://example.com/` | Status: Valid (Launchable); Scheme: `https`; Host: `example.com`; Port: `Default (443)`; Open Externally button active; zero warning indicators. | `screen_phone_m56_case1_ordinary.png` | `dump_case1_ordinary.xml` |
| **2** | Domain Fronting in Subdomains | `https://paypal.com.evil.example/login` | Status: Valid; Scheme: `https`; Host: `paypal.com.evil.example`; Observations: *"Hostname contains an embedded domain pattern ('paypal.com') within its subdomains; the actual destination root is 'evil.example'."* | `screen_phone_m56_case2_subdomain.png` | `dump_case2_subdomain.xml` |
| **3** | Direct Numerical IP & Non-Standard Port | `http://37.77.150.214:8080/msi/setup.msi` | Status: Valid; Scheme: `http`; Host: `37.77.150.214`; Port: `8080`; Observations: *"Destination uses a numerical IP address..."*, *"Destination connects to non-standard network port :8080"*, *"Uses unencrypted HTTP connection"*. | `screen_phone_m56_case3_ip_port.png` | `dump_case3_ip_port.xml` |
| **4** | Punycode ASCII Domain | `https://xn--e1afmkfd.xn--p1ai/` | Status: Valid; Scheme: `https`; Host: `xn--e1afmkfd.xn--p1ai`; Observations: *"Hostname contains a punycode label ('xn--') used for internationalized domain names."* | `screen_phone_m56_case4_punycode.png` | `dump_case4_punycode.xml` |
| **5** | Actionable Non-Web Scheme (`tel:`) | `tel:+15551234567` | Status: Rejected; Warning Banner: *"Unsupported link type: Scheme 'tel:' is not supported for web navigation."*; Open Externally button disabled; zero external dialer invoked. | `screen_phone_m56_case5_unsupported.png` | `dump_case5_unsupported.xml` |
| **6** | Malformed Missing Scheme | `example.com/login` | Status: Rejected; Warning Banner: *"Missing web scheme (http:// or https://)."*; Open Externally button disabled. | `screen_phone_m56_case6_malformed.png` | `dump_case6_malformed.xml` |
| **7** | Long Input Near Limit | `https://example.com/test?query=...` (400+ characters) | Status: Valid; parsed cleanly; query parameters counted; full URL rendered in scrollable container without UI overflow or clipping. | `screen_phone_m56_case7_long.png` | `dump_case7_long.xml` |
| **8** | Offline Air-Gap Verification | `https://share.google/1CUx4XF0XRwYPB1HR` (Airplane Mode / Wi-Fi & Cellular Off) | Evaluated 100% offline with zero network connectivity; Shortener observation rendered immediately (*"Destination uses a URL shortening or link redirection domain..."*); connectivity cleanly restored after test. | `screen_phone_m56_case8_offline.png` | `dump_case8_offline.xml` |

All 8 screenshot PNGs and 8 UI XML dumps are permanently preserved under `docs/evidence/module_56/`.

---

## 7. Reconciled Quota Discrepancy Technical Root Cause Analysis

### Background of Observed Values
- In **Module 54**, the live authenticated Cloud AI request against Render/Groq decremented the test user quota from **15 to 14** (recorded in `LIVE_CLOUD_AI_VERIFICATION_EVIDENCE.md`).
- In **Module 55**, during subsequent device lifecycle testing, the account profile inspection displayed **15 of 15 remaining** (recorded in `dump_acc.xml` and `dump_acc_scroll.xml`).

### Technical Root Cause
The technical discrepancy arose because the hosted backend service on Render is deployed under Render's **Free Web Service tier** using an in-memory quota store.

In `trustcue-backend/backend/src/trustcue_backend/core/quota.py`:
```python
class InMemoryQuotaStore:
    def __init__(self, default_daily_quota: int = 15):
        self.default_daily_quota = default_daily_quota
        self._usage: dict[tuple[str, str], int] = {}
```
1. **Container Ephemerality:** Under Render's free tier, containers spin down automatically after 15 minutes of inbound HTTP inactivity. When a new request arrives, a fresh container process is spun up.
2. **Volatile Storage:** `InMemoryQuotaStore` maintains its usage counters in Python heap memory (`self._usage`). It does not persist counters to PostgreSQL or Redis.
3. **Reset Behavior:** When the backend spun down between Module 54 and Module 55, the container memory was re-initialized. Upon the test user's subsequent login in Module 55, `get_user_quota(user_id)` read an empty dictionary and returned the full default quota of `15`.

**Phase 7 Architectural Resolution:** Persistent distributed quota storage backed by Supabase PostgreSQL is scheduled for implementation in Phase 7 (Modules 63 & 64).

---

## 8. README.md Historical Claim Reconciliation

During the Module 56 baseline audit, line 12 of `trustcue-mobile/README.md` was found to contain an unverified claim originating from Module 50:
> *" ...execution of real-world test fixtures (Testing Data/) spanning 26 scam scenarios, 6 benign counterexamples (...), 57 offline-inspected links, 19 screenshot OCR tests, and 9 QR code inspections on physical Vivo V2207..."*

### Correction Applied
As established in Module 52, only fixture `IMG-02` was executed live on hardware in Module 50; the remaining 18 physical screenshot UI journeys were deferred to Module 52 and Module 57. Line 12 was updated to accurately reflect project reality:
```markdown
...spanning 26 scam scenarios, 6 benign counterexamples (no indicators matched in the six tested benign fixtures), 57 offline-inspected links, on-device OCR benchmarks, and QR code inspections on physical Vivo V2207 (Android 14 API 34; see authoritative [Completion Register](docs/COMPLETION_REGISTER.md) and evidence dossiers in docs/evidence/ for verified hardware journeys and carried-forward items)...
```

---

## 9. Verification & Gate Checks

1. **Dart Code Formatting:**
   ```bash
   dart format --output=none --set-exit-if-changed lib test
   # Result: Formatted 328 files (0 changed) in 1.20 seconds.
   ```
2. **Static Code Analysis:**
   ```bash
   flutter analyze lib test
   # Result: Analyzing 2 items... No issues found! (ran in 56.4s)
   ```
3. **Automated Test Suite:**
   ```bash
   flutter test
   # Result: 00:56 +1048: All tests passed!
   ```
   - 1,025 existing baseline tests passed.
   - 23 new comprehensive tests in `extended_link_corpus_test.dart` passed.
4. **Physical Android Release Build:**
   - Script: `frontend/scripts/build_release.ps1 -Install`
   - SHA-256: `3409B8B0913350BD317DE6D2A17F1AFA0CD0502E74A513FD0946F1F210AFE666`
   - Installation to Vivo V2207: **Success**

---

## 10. Conclusion & Forward Status

Module 56 successfully completes the comprehensive link and scheme inspection corpus audit. The `UrlInspectionService` and `InputLinkController` are robust, fully verified against all 57 corpus fixtures and 16 boundary conditions, and operating strictly offline with zero external launch risk.

- **Module 56 Status:** **COMPLETE**
- **Next Assigned Milestone:** **MODULE 57** (Edge-Case Text Intake & Native Hardware Intake Testing)
