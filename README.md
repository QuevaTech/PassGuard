<p align="center">
  <img src="macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png" width="108" alt="PassGuard Vault"/>
</p>

<h1 align="center">PassGuard Vault</h1>

<p align="center">
  <strong>A private notebook for your digital life.</strong><br/>
  Offline by design. Yours by principle.
</p>

<p align="center">
  <img alt="License" src="https://img.shields.io/badge/license-AGPL--3.0%20%2B%20Commons%20Clause-blue"/>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.0%2B-02569B?logo=flutter&logoColor=white"/>
  <img alt="Platform" src="https://img.shields.io/badge/platform-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Linux%20%7C%20Windows-lightgrey"/>
  <img alt="Encryption" src="https://img.shields.io/badge/encryption-AES--256--GCM-brightgreen"/>
  <img alt="KDF" src="https://img.shields.io/badge/KDF-Argon2id-orange"/>
</p>

---

Most password managers are built around a question: *"How do we sync your data across all your devices?"*

PassGuard Vault starts from a different question: **"Who should your data belong to?"**

The answer is a private notebook — not a platform.

---

## The Notebook Philosophy

Think about a physical notebook. It doesn't require an account. It doesn't phone home. It doesn't get breached when a company's servers are compromised. It doesn't expire when you stop paying a subscription. When you lose it, only the person who physically holds it can read it — and even then, only if they can break the lock.

PassGuard Vault is that notebook, built for the digital world.

| | Notebook Approach | Platform Approach |
| --- | --- | --- |
| **Where is your data?** | On your device only | On company servers |
| **Who can access it?** | Only you | You + the vendor + breach victims |
| **What happens if the company closes?** | Nothing — you still have your file | You lose access |
| **What happens if servers go down?** | Nothing — fully offline | You're locked out |
| **What does breach exposure look like?** | Zero — nothing to breach | Millions of credentials at once |
| **What does "backup" mean?** | You copy your encrypted file | You hope their backup works |

Most competitors position sync and cloud access as features. We position their absence as a guarantee.

Your `.pgvault` file is just a file — encrypted, portable, and entirely under your control. Store it on your phone, a USB drive, a local folder, or an air-gapped machine. Share it with nobody, or back it up anywhere. It is meaningless without your master password, and your master password never leaves your head.

**Other apps are services. PassGuard Vault is a tool.**

---

## How We Compare

| Feature | PassGuard Vault | LastPass | 1Password | Bitwarden | KeePass | Dashlane |
| --- | :---: | :---: | :---: | :---: | :---: | :---: |
| Fully offline (no cloud) | ✅ | ❌ | ❌ | ⚠️ | ✅ | ❌ |
| No account required | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| No subscription fee | ✅ | ❌ | ❌ | ⚠️ | ✅ | ❌ |
| AES-256-**GCM** (authenticated) | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Argon2id KDF (always-on, non-downgradable) | ✅ | ❌ | ❌ | ⚠️ | ✅ | ⚠️ |
| Native biometric unlock | ✅ | ✅ | ✅ | ✅ | ⚠️ | ✅ |
| Native mobile app | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| Modern native UI (Material Design 3) | ✅ | ⚠️ | ⚠️ | ⚠️ | ❌ | ⚠️ |
| Auto-lock & session timeout | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Encrypted backup | ✅ | ⚠️ | ⚠️ | ✅ | ✅ | ⚠️ |
| Open source | ✅ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Zero data sent to any server | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| Memory-safe key handling | ✅ | — | — | — | ❌ | — |
| Documented CVEs | **None** | **Multiple** | None | None | **CVE-2023-32784** | None |
| Proven breach / incident history | **None** | **2022 breach** | None | None | **2023 exploit** | None |

> ✅ Full support &nbsp;·&nbsp; ⚠️ Partial / optional / plugin required &nbsp;·&nbsp; ❌ Not supported &nbsp;·&nbsp; — Not applicable
>
> Bitwarden Argon2id: optional, not default — PBKDF2 remains default and is vulnerable to server-side iteration downgrade attacks. Dashlane: uses Argon2**d**, not Argon2**id** — lacks side-channel resistance.

---

## Why Not KeePass?

KeePass is the most well-known offline alternative — and it deserves respect for that. But after two decades of design decisions, it carries baggage that PassGuard Vault was built to leave behind.

### CVE-2023-32784 — The Master Password Was Never Safe in Memory

In May 2023, a critical vulnerability was disclosed: an attacker with access to a memory dump of the machine running KeePass could **reconstruct the master password character by character** from heap memory. The root cause was KeePass's custom `SecureTextBoxEx` input field, which leaves remnants of each typed character in the .NET managed heap — remnants that persist long after the app is closed, and even survive hibernation and sleep cycles.

This is not a theoretical edge case. A working proof-of-concept exploit was publicly released within days.

PassGuard Vault derives the session key through Argon2id and holds only the resulting **raw key bytes** in memory — never the master password string itself. The key is cleared on auto-lock. There is no equivalent attack surface.

### AES-256-CBC vs AES-256-GCM

KeePass defaults to AES-256 in **CBC mode**, which provides confidentiality but no authentication. A tampered ciphertext can be silently decrypted to wrong data without any error. PassGuard Vault uses **GCM mode** exclusively — every encrypted block includes a cryptographic authentication tag. Any modification to the ciphertext is detected and rejected before decryption.

### No Native Mobile App

KeePass has no official mobile application. On iOS and Android, users depend on third-party apps (KeePassDX, Keepass2Android, Strongbox) built by independent developers with no official support, inconsistent update cadence, and varying security postures. PassGuard Vault ships a single, unified codebase across all platforms.

### Secure Clipboard — Not a Keyboard Hack

KeePass relies on "AutoType" — a keyboard simulation mechanism that sends keystrokes to the focused window. It is fragile, incompatible with many modern apps, and indistinguishable from a keylogger at the OS level. PassGuard Vault copies credentials to the clipboard via a dedicated secure channel and provides a one-tap clipboard wipe — no keyboard simulation, no background typing.

### Biometrics Require a Plugin

Fingerprint and Face ID unlock in KeePass require third-party plugins. PassGuard Vault ships biometric authentication as a first-class, built-in feature on every supported platform.

### A 2003 UI on a 2024 Device

KeePass was designed for Windows XP. Its interface is a direct descendant of that era — dense, modal-heavy, and foreign on macOS, Linux, and mobile. PassGuard Vault is built with Flutter's Material Design 3, with full dark/light/system theme support and a layout designed for modern screens.

---

## The Freedom Advantage

Brian Tracy identifies three levels where people get stuck: **fear, dependency, and reactive thinking.** Most password managers are built in a way that keeps you in all three.

- **Fear** — your data lives on someone else's server. When they get breached (and they do), you pay the price.
- **Dependency** — subscriptions, accounts, vendor lock-in. The day they go down, so does your access.
- **Reactive thinking** — you trust a third party to keep you safe instead of taking ownership of your own security posture.

PassGuard Vault is built around the opposite philosophy:

- **Ownership** — your vault file lives on your device. Only you hold the key.
- **Independence** — no account, no server, no monthly fee. It works offline, always.
- **Proactive control** — you decide what gets backed up, where it goes, and who can access it.

**Security should give you peace of mind — not another thing to worry about.**

---

## Competitive Advantages

### Military-Grade Encryption Stack

- **AES-256-GCM** — authenticated encryption that detects tampering at the byte level
- **Argon2id KDF** — 64 MB memory cost, 3 iterations, 4 parallel lanes. Argon2id is the OWASP-recommended standard: it resists both GPU-based brute-force attacks and side-channel attacks. Bitwarden offers it as an optional setting (PBKDF2 is still the default, and a known design flaw allows server-side iteration downgrade). Dashlane uses Argon2**d** — an older variant without side-channel resistance. LastPass and 1Password rely on PBKDF2. In PassGuard Vault, Argon2id is hardcoded — it cannot be disabled, downgraded, or overridden by any server or configuration.
- Every entry is encrypted with a **unique IV** — even if two passwords are identical, their ciphertext is not

### Zero-Knowledge by Design

The master password is never stored. Ever. A SHA-256 hash of the derived key is kept in the vault header solely to verify the correct password at unlock time. No plaintext. No recovery backdoor.

### Resilient Backup Format

The `.pgvault` format is a fully encrypted archive. You can store it on a USB drive, email it to yourself, or keep it in a folder — it is safe on any medium because it is encrypted before it ever leaves the app.

### Cross-Platform, No Compromise

Runs natively on **iOS · Android · macOS · Linux · Windows** — the same vault file, the same encryption, the same experience. No platform gets a watered-down version.

---

## Built for Growth

The best investment you can make is in your own capabilities. PassGuard Vault is designed to grow with you:

- **Password Generator** — configurable length, character sets, strength scoring (0–100). Build the habit of using unique, strong passwords across every account.
- **Vault Health Stats** — see your entry count, categories, and coverage at a glance. Know where you're exposed before someone else finds out.
- **Merge & Replace Import** — migrate from another manager without losing data. You are never locked in or locked out.
- **Multi-language** — Turkish, English, German, French, Arabic. Security is a universal right.

---

## Security Architecture

```text
Master Password
      │
      ▼
Argon2id (64MB · 3 iter · 4 lanes)
      │
      ▼
AES-256 Key (in memory only)
      │
      ├─► Vault Header  →  key_hash (SHA-256, for verification)
      │
      └─► Per-Entry Encryption  →  AES-256-GCM + unique IV + auth tag
```

The key exists in memory only for the duration of an unlocked session. Auto-lock clears it. Biometric re-authentication restores it — without re-deriving from the master password.

---

## Getting Started

### Prerequisites

- Flutter SDK >= 3.0.0
- Dart >= 3.0.0
- Xcode (iOS / macOS) · Android Studio (Android)

### Run from source

```bash
git clone https://github.com/quevatech/passguard-vault.git
cd passguard_vault_v0

flutter pub get
flutter run
```

### Release build

```bash
flutter build macos --release   # macOS
flutter build apk --release     # Android
flutter build ios --release     # iOS
```

---

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a pull request.

All contributors must sign the **Contributor License Agreement (CLA)** — handled automatically by [CLA Assistant](https://cla-assistant.io) when you open a PR.

---

## License

Licensed under **AGPL-3.0 with Commons Clause**.

Free to use, study, and modify for personal and non-commercial purposes. Selling this software or offering it as a hosted/managed service requires explicit written permission from the copyright holder.

See [LICENSE](LICENSE) for full terms.

---

<p align="center">
  Developed by <a href="https://queva.tech">quevatech</a>
</p>
