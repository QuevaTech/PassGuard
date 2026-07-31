import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passguard_vault/services/ssh_key_service.dart';

void main() {
  test('Ed25519 generation matches the RFC 8032 public-key test vector', () {
    final publicKey = SshKeyService.ed25519PublicKeyFromSeed(
      Uint8List.fromList(
        _hexToBytes(
          '9d61b19deffd5a60ba844af492ec2cc4'
          '4449c5697b326919703bac031cae7f60',
        ),
      ),
    );
    expect(
      _toHex(publicKey),
      'd75a980182b10ab7d54bfed3c964073a'
      '0ee172f3daa62325af021a68f707511a',
    );
  });

  test('generates every advertised algorithm in standard SSH formats',
      () async {
    for (final algorithm in SshKeyAlgorithm.values) {
      final keyPair = await SshKeyService.generateKeyPair(
        algorithm: algorithm,
        comment: 'deploy key',
      );

      expect(keyPair.algorithm, algorithm);
      expect(keyPair.publicKey, endsWith(' deploy-key'));
      expect(_keyType(keyPair.publicKey), _expectedKeyType(algorithm));
      expect(
        keyPair.privateKey,
        allOf(
          startsWith(algorithm.rsaBits == null
              ? '-----BEGIN OPENSSH PRIVATE KEY-----'
              : '-----BEGIN RSA PRIVATE KEY-----'),
          endsWith('\n'),
        ),
      );

      final blob = base64Decode(keyPair.publicKey.split(' ')[1]);
      expect(_readSshString(blob, 0), _expectedKeyType(algorithm));
      final expectedFingerprint =
          'SHA256:${base64Encode(sha256.convert(blob).bytes).replaceAll('=', '')}';
      expect(keyPair.fingerprint, expectedFingerprint);

      if (algorithm == SshKeyAlgorithm.rsa3072) {
        _verifyRsaPrivateKey(keyPair.privateKey);
        final publicExponentLength = _readUint32(blob, 11);
        final modulusOffset = 15 + publicExponentLength;
        final modulusLength = _readUint32(blob, modulusOffset);
        expect(modulusLength, greaterThanOrEqualTo(385),
            reason: 'RSA modulus must be encoded as a positive SSH mpint');
      }
    }
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('OpenSSH accepts every generated private key on desktop', () async {
    if (!Platform.isMacOS && !Platform.isLinux) return;

    final tempDir = await Directory.systemTemp.createTemp('passguard-ssh-');
    try {
      for (final algorithm in SshKeyAlgorithm.values) {
        final keyPair = await SshKeyService.generateKeyPair(
          algorithm: algorithm,
          comment: 'interop',
        );
        final keyFile =
            File('${tempDir.path}${Platform.pathSeparator}${algorithm.name}');
        await keyFile.writeAsString(keyPair.privateKey, flush: true);
        await Process.run('chmod', ['600', keyFile.path]);

        final result =
            await Process.run('ssh-keygen', ['-y', '-f', keyFile.path]);
        expect(result.exitCode, 0,
            reason: '${algorithm.label}: ${result.stderr}');
        expect(
          _keyType(result.stdout as String),
          _expectedKeyType(algorithm),
        );
      }
    } finally {
      await tempDir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 60)));
}

List<int> _hexToBytes(String value) => [
      for (var index = 0; index < value.length; index += 2)
        int.parse(value.substring(index, index + 2), radix: 16),
    ];

String _toHex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

String _expectedKeyType(SshKeyAlgorithm algorithm) {
  switch (algorithm) {
    case SshKeyAlgorithm.ed25519:
      return 'ssh-ed25519';
    case SshKeyAlgorithm.rsa2048:
    case SshKeyAlgorithm.rsa3072:
    case SshKeyAlgorithm.rsa4096:
      return 'ssh-rsa';
    case SshKeyAlgorithm.ecdsaP256:
      return 'ecdsa-sha2-nistp256';
    case SshKeyAlgorithm.ecdsaP384:
      return 'ecdsa-sha2-nistp384';
  }
}

String _keyType(String publicKey) =>
    publicKey.trim().split(RegExp(r'\s+')).first;

String _readSshString(List<int> bytes, int offset) {
  final length = _readUint32(bytes, offset);
  return utf8.decode(bytes.sublist(offset + 4, offset + 4 + length));
}

void _verifyRsaPrivateKey(String privateKey) {
  final privateDer = base64Decode(
    privateKey.split('\n').where((line) => !line.startsWith('-----')).join(),
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
