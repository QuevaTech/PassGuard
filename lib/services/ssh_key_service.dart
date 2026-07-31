import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:pointycastle/export.dart';

import 'encryption_service.dart';

/// A locally generated SSH RSA key pair. The private key is PKCS#1 PEM and
/// the public key is in the OpenSSH `ssh-rsa` format.
class GeneratedSshKeyPair {
  final String privateKey;
  final String publicKey;
  final String fingerprint;

  const GeneratedSshKeyPair({
    required this.privateKey,
    required this.publicKey,
    required this.fingerprint,
  });
}

class SshKeyService {
  static const int rsaBits = 3072;

  /// Creates a modern RSA key pair without invoking an external program.
  /// Generation happens in a background isolate so the UI remains responsive.
  static Future<GeneratedSshKeyPair> generateRsaKeyPair({
    String comment = 'passguard',
  }) async {
    final result = await compute(_generateRsaKeyPair, {
      'bits': rsaBits,
      'comment': _safeComment(comment),
    });
    return GeneratedSshKeyPair(
      privateKey: result['private_key']!,
      publicKey: result['public_key']!,
      fingerprint: result['fingerprint']!,
    );
  }

  static String _safeComment(String comment) {
    final cleaned = comment.trim().replaceAll(RegExp(r'\s+'), '-');
    if (cleaned.isEmpty) return 'passguard';
    return cleaned.substring(0, cleaned.length > 80 ? 80 : cleaned.length);
  }
}

// Top-level function required by [compute].
Map<String, String> _generateRsaKeyPair(Map<String, dynamic> arguments) {
  // Fortuna requires exactly 256 bits of seed material.
  final seed = EncryptionService.generateSecureRandomBytes(32);
  final random = FortunaRandom()..seed(KeyParameter(seed));
  final keyGenerator = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(
          BigInt.from(65537),
          arguments['bits'] as int,
          64,
        ),
        random,
      ),
    );

  final pair = keyGenerator.generateKeyPair();
  final publicKey = pair.publicKey as RSAPublicKey;
  final privateKey = pair.privateKey as RSAPrivateKey;
  final publicBlob = _openSshPublicBlob(publicKey);
  final comment = arguments['comment'] as String;
  final openSshPublicKey = 'ssh-rsa ${base64Encode(publicBlob)} $comment';
  final fingerprint =
      'SHA256:${base64Encode(sha256.convert(publicBlob).bytes).replaceAll('=', '')}';

  // Best-effort overwrite of random seed after key generation.
  seed.fillRange(0, seed.length, 0);

  return {
    'private_key': _encodeRsaPrivateKeyPem(privateKey),
    'public_key': openSshPublicKey,
    'fingerprint': fingerprint,
  };
}

Uint8List _openSshPublicBlob(RSAPublicKey key) {
  return _concatBytes([
    _sshString(utf8.encode('ssh-rsa')),
    _sshMpint(key.publicExponent!),
    _sshMpint(key.modulus!),
  ]);
}

Uint8List _sshString(List<int> value) => _concatBytes([
      _uint32(value.length),
      Uint8List.fromList(value),
    ]);

Uint8List _sshMpint(BigInt value) {
  var bytes = _unsignedBigInt(value);
  // SSH mpint values are signed two's-complement integers. Prefix a zero when
  // the high bit is set so an RSA modulus is not parsed as a negative value.
  if (bytes.first & 0x80 != 0) {
    bytes = _concatBytes([
      Uint8List.fromList([0]),
      bytes
    ]);
  }
  return _sshString(bytes);
}

Uint8List _uint32(int value) => Uint8List.fromList([
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ]);

String _encodeRsaPrivateKeyPem(RSAPrivateKey key) {
  final p = key.p!;
  final q = key.q!;
  final d = key.privateExponent!;
  final der = _derSequence([
    _derInteger(BigInt.zero),
    _derInteger(key.modulus!),
    _derInteger(key.publicExponent!),
    _derInteger(d),
    _derInteger(p),
    _derInteger(q),
    _derInteger(d % (p - BigInt.one)),
    _derInteger(d % (q - BigInt.one)),
    _derInteger(q.modInverse(p)),
  ]);
  final encoded = base64Encode(der);
  final lines = <String>[
    '-----BEGIN RSA PRIVATE KEY-----',
    for (var index = 0; index < encoded.length; index += 64)
      encoded.substring(
          index, index + 64 > encoded.length ? encoded.length : index + 64),
    '-----END RSA PRIVATE KEY-----',
  ];
  return lines.join('\n');
}

Uint8List _derSequence(List<Uint8List> values) {
  final body = _concatBytes(values);
  return _concatBytes([
    Uint8List.fromList([0x30]),
    _derLength(body.length),
    body
  ]);
}

Uint8List _derInteger(BigInt value) {
  var bytes = _unsignedBigInt(value);
  if (bytes.isEmpty) bytes = Uint8List.fromList([0]);
  if (bytes.first & 0x80 != 0) {
    bytes = _concatBytes([
      Uint8List.fromList([0]),
      bytes
    ]);
  }
  return _concatBytes([
    Uint8List.fromList([0x02]),
    _derLength(bytes.length),
    bytes
  ]);
}

Uint8List _derLength(int length) {
  if (length < 128) return Uint8List.fromList([length]);
  final bytes = <int>[];
  var remaining = length;
  while (remaining > 0) {
    bytes.insert(0, remaining & 0xff);
    remaining >>= 8;
  }
  return Uint8List.fromList([0x80 | bytes.length, ...bytes]);
}

Uint8List _unsignedBigInt(BigInt value) {
  if (value == BigInt.zero) return Uint8List.fromList([0]);
  final bytes = <int>[];
  var remaining = value;
  while (remaining > BigInt.zero) {
    bytes.insert(0, (remaining & BigInt.from(0xff)).toInt());
    remaining >>= 8;
  }
  return Uint8List.fromList(bytes);
}

Uint8List _concatBytes(List<Uint8List> values) {
  final length = values.fold<int>(0, (total, value) => total + value.length);
  final result = Uint8List(length);
  var offset = 0;
  for (final value in values) {
    result.setAll(offset, value);
    offset += value.length;
  }
  return result;
}
