import 'package:flutter_test/flutter_test.dart';
import 'package:passguard_vault/models/vault_entry.dart';

void main() {
  test('SSH key fields stay inside the encrypted entry payload', () {
    final entry = VaultEntry(
      id: 'ssh-1',
      type: VaultEntryType.sshKey,
      title: 'Production deploy key',
      category: 'Servers',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      privateKey: '-----BEGIN RSA PRIVATE KEY-----\nsecret',
      publicKey: 'ssh-rsa AAAA production',
      keyFingerprint: 'SHA256:fingerprint',
    );

    final encrypted = entry.toEncryptedJson();
    expect(encrypted, isNot(contains('private_key')));
    expect(encrypted, isNot(contains('public_key')));
    expect(entry.getSensitiveFields(),
        containsPair('private_key', contains('secret')));
    expect(entry.getSensitiveFields(),
        containsPair('public_key', contains('ssh-rsa')));
  });

  test('certificate attachment metadata and bytes are encrypted fields', () {
    final entry = VaultEntry(
      id: 'cert-1',
      type: VaultEntryType.certificate,
      title: 'VPN client certificate',
      category: 'Certificates',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      attachmentBase64: 'AAEC',
      attachmentFileName: 'vpn-client.p12',
      attachmentMimeType: 'application/x-pkcs12',
      credentialKind: 'Client certificate',
    );

    final encrypted = entry.toEncryptedJson();
    final sensitive = entry.getSensitiveFields();
    expect(encrypted, isNot(contains('attachment_base64')));
    expect(sensitive['attachment_base64'], 'AAEC');
    expect(sensitive['attachment_file_name'], 'vpn-client.p12');
  });

  test('new entry types round-trip through vault JSON metadata', () {
    final json = {
      'id': 'cert-2',
      'type': 'certificate',
      'title': 'Root CA',
      'category': 'Certificates',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
    };

    expect(VaultEntry.fromJson(json).type, VaultEntryType.certificate);
  });
}
