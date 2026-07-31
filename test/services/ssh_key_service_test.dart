import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passguard_vault/services/ssh_key_service.dart';

void main() {
  test('generates a 3072-bit RSA key in standard PEM and OpenSSH formats',
      () async {
    final keyPair =
        await SshKeyService.generateRsaKeyPair(comment: 'deploy key');

    expect(keyPair.privateKey, startsWith('-----BEGIN RSA PRIVATE KEY-----'));
    expect(keyPair.privateKey, endsWith('-----END RSA PRIVATE KEY-----'));
    expect(keyPair.publicKey, startsWith('ssh-rsa '));
    expect(keyPair.publicKey, endsWith(' deploy-key'));

    final blob = base64Decode(keyPair.publicKey.split(' ')[1]);
    expect(utf8.decode(blob.sublist(4, 11)), 'ssh-rsa');
    final publicExponentLength = _readUint32(blob, 11);
    final modulusOffset = 15 + publicExponentLength;
    final modulusLength = _readUint32(blob, modulusOffset);
    expect(modulusLength, greaterThanOrEqualTo(385),
        reason: 'RSA 3072 modulus must be encoded as a positive SSH mpint');

    final privateDer = base64Decode(
      keyPair.privateKey
          .split('\n')
          .where((line) => !line.startsWith('-----'))
          .join(),
    );
    final integers = _readPkcs1Integers(privateDer);
    expect(integers, hasLength(9));
    expect(integers[0], BigInt.zero);
    expect(integers[1], integers[4] * integers[5]);
    expect(
      (integers[2] * integers[3]) %
          ((integers[4] - BigInt.one) * (integers[5] - BigInt.one)),
      BigInt.one,
      reason: 'PEM must contain a mathematically valid RSA private key',
    );

    final expectedFingerprint =
        'SHA256:${base64Encode(sha256.convert(blob).bytes).replaceAll('=', '')}';
    expect(keyPair.fingerprint, expectedFingerprint);
  }, timeout: const Timeout(Duration(seconds: 60)));
}

int _readUint32(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];

List<BigInt> _readPkcs1Integers(List<int> der) {
  var offset = 0;
  expect(der[offset++], 0x30);
  offset += _derLengthByteCount(der, offset);
  final values = <BigInt>[];
  while (offset < der.length) {
    expect(der[offset++], 0x02);
    final length = _readDerLength(der, offset);
    offset += _derLengthByteCount(der, offset);
    final bytes = der.sublist(offset, offset + length);
    offset += length;
    values.add(_bytesToBigInt(bytes));
  }
  return values;
}

int _derLengthByteCount(List<int> bytes, int offset) {
  final first = bytes[offset];
  return first < 0x80 ? 1 : 1 + (first & 0x7f);
}

int _readDerLength(List<int> bytes, int offset) {
  final first = bytes[offset];
  if (first < 0x80) return first;
  var value = 0;
  for (var index = 0; index < (first & 0x7f); index++) {
    value = (value << 8) | bytes[offset + 1 + index];
  }
  return value;
}

BigInt _bytesToBigInt(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}
