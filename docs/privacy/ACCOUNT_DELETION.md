# TrustCue Account and Data Deletion Instructions

**Effective Date:** October 18, 2026  
**Application:** TrustCue (`io.github.muhammadtaimoorajmal.trustcue`)  
**Developer:** Muhammad Taimoor Ajmal  
**Contact Email:** `muhammadtaimoorajmal@gmail.com`  

---

## Overview
In accordance with Google Play's User Data Policy and account deletion requirements, TrustCue provides two direct, discoverable pathways for users to delete their account and associated data:
1. **In-App Deletion:** Directly within the TrustCue mobile application while logged in.
2. **External Web / Email Deletion:** A public mechanism allowing users who have uninstalled the app or cannot access their device to request complete account and data removal.

---

## Pathway 1: In-App Account Deletion (Recommended)

If you have the TrustCue application installed on your device:

1. Open **TrustCue**.
2. Tap the **Account** button in the top navigation bar.
3. If not already signed in, sign in with your email and password.
4. Scroll to the bottom of the Account screen and tap **Delete Account** (styled in red).
5. A confirmation dialog will appear explaining the permanent nature of the action:
   - Your account credentials and user profile will be permanently deleted from our servers.
   - Your daily quota history will be erased.
   - All cloud-synchronized report metadata will be purged.
   - All locally saved reports on this device belonging to your account will be cleared.
6. Enter your current account password to re-authenticate and confirm ownership.
7. Tap **Permanently Delete Account**.

**Result:** Your account is immediately deleted on the backend using an atomic database cascade (`ON DELETE CASCADE`), local hardware Keystore tokens are cleared, and the app resets to Guest Mode.

---

## Pathway 2: External Web / Email Deletion Request

If you have uninstalled the app, lost your device, or cannot log in:

### How to Submit a Request
Send an email to our dedicated data privacy mailbox:
- **Recipient:** `muhammadtaimoorajmal@gmail.com`
- **Subject:** `TrustCue Account Deletion Request`
- **Required Details:**
  1. The **exact email address** associated with your registered TrustCue account.
  2. A statement confirming: *"I request the permanent deletion of my TrustCue account and all associated cloud data."*

### Verification & Processing Timeline
1. **Identity Verification:** To prevent unauthorized deletion requests, our system sends a one-time verification challenge or verification link to the registered email address.
2. **Execution:** Upon successful confirmation, our system executes an administrative account purge:
   - Your Supabase authentication user record (`auth.users`) is permanently deleted.
   - Your profile record (`public.profiles`) is deleted.
   - Your daily quota records (`public.ai_usage_quotas`) are deleted.
   - Any cloud-synchronized report metadata (`public.synced_reports`) is permanently deleted.
3. **Timeline:** Deletion requests are processed and completed within **7 business days**.
4. **Confirmation:** You will receive a final confirmation email once your account and all associated data have been permanently purged.

---

## Data Retention Exceptions & Disclosures
- **No Residual Data Retained:** TrustCue does not retain inactive, frozen, or suspended accounts. Deletion is complete, irreversible, and permanent.
- **Local Data Notice:** Because guest-mode reports and locally saved reports reside in app-private sandboxed SQLite storage on your physical device, uninstalling the TrustCue application or clearing app storage in Android System Settings (`Settings -> Apps -> TrustCue -> Clear Storage`) will instantly destroy all local data on the device.

