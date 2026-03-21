# Contributing to PassGuard Vault

Thank you for your interest in contributing. This document explains the process for submitting changes and the agreements required before contributions can be accepted.

---

## Contributor License Agreement (CLA)

Before your pull request can be merged, you must sign the **PassGuard Vault Contributor License Agreement**.

This is a one-time step. The CLA ensures that:

- You confirm you have the right to contribute the code you submit
- quevatech retains the ability to license the project (including under commercial terms if applicable)
- Your contribution does not introduce third-party IP or license conflicts

### How it works

PassGuard Vault uses **[CLA Assistant](https://cla-assistant.io)** — a free tool developed by SAP that automates CLA signing via GitHub.

1. Open or submit a pull request
2. The CLA Assistant bot will comment on your PR automatically
3. Click the link in the bot's comment and sign with your GitHub account — one click, no forms
4. Once signed, the check turns green and your PR can proceed

You only sign once. Subsequent PRs from the same account are automatically recognized.

> If you are contributing on behalf of a company, ensure your employer has authorized the contribution and that you have the right to bind them to the CLA.

---

## How to Contribute

### Reporting Issues

- Search existing issues before opening a new one
- Include your OS, Flutter version, and steps to reproduce
- For security vulnerabilities, **do not open a public issue** — contact [hasan@queva.tech](mailto:hasan@queva.tech) directly

### Submitting a Pull Request

1. Fork the repository
2. Create a branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes — keep commits focused and descriptive
4. Run existing tests:
   ```bash
   flutter test
   ```
5. Push and open a PR against `main`
6. Sign the CLA when prompted by the bot

### Code Style

- Follow the existing Dart/Flutter conventions in the codebase
- Run `flutter analyze` before submitting — no new warnings
- Do not add dependencies without prior discussion in an issue

### What We Welcome

- Bug fixes
- Security improvements
- Localization additions (new languages)
- Performance improvements
- Documentation improvements

### What We Do Not Accept

- Cloud sync or server-side features — PassGuard Vault is offline by design
- Features that require accounts or external services
- UI changes without a corresponding issue and discussion

---

## Development Setup

```bash
git clone https://github.com/QuevaTech/PassQuard.git
cd PassQuard

flutter pub get
flutter run
```

Requires Flutter SDK >= 3.0.0. See [README.md](README.md) for full prerequisites.

---

## License

By contributing, you agree that your contributions will be licensed under the project's [AGPL-3.0](LICENSE) license, subject to the terms of the CLA.

---

*Developed by [quevatech](https://queva.tech)*
