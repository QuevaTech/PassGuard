import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:pointycastle/export.dart';

import 'encryption_service.dart';

enum SshKeyAlgorithm {
  ed25519,
  rsa2048,
  rsa3072,
  rsa4096,
  ecdsaP256,
  ecdsaP384,
}

extension SshKeyAlgorithmDetails on SshKeyAlgorithm {
  String get label {
    switch (this) {
      case SshKeyAlgorithm.ed25519:
        return 'Ed25519';
      case SshKeyAlgorithm.rsa2048:
        return 'RSA 2048';
      case SshKeyAlgorithm.rsa3072:
        return 'RSA 3072';
      case SshKeyAlgorithm.rsa4096:
        return 'RSA 4096';
      case SshKeyAlgorithm.ecdsaP256:
        return 'ECDSA P-256';
      case SshKeyAlgorithm.ecdsaP384:
        return 'ECDSA P-384';
    }
  }

  String get subtitle {
    switch (this) {
      case SshKeyAlgorithm.ed25519:
        return 'Recommended · modern, compact and fast';
      case SshKeyAlgorithm.rsa2048:
        return 'Legacy compatibility';
      case SshKeyAlgorithm.rsa3072:
        return 'Broad compatibility · recommended RSA';
      case SshKeyAlgorithm.rsa4096:
        return 'For policies that explicitly require it';
      case SshKeyAlgorithm.ecdsaP256:
        return 'NIST curve · broad modern support';
      case SshKeyAlgorithm.ecdsaP384:
        return 'NIST curve · higher security margin';
    }
  }

  bool get isRecommended => this == SshKeyAlgorithm.ed25519;
  bool get isLegacy => this == SshKeyAlgorithm.rsa2048;

  int? get rsaBits {
    switch (this) {
      case SshKeyAlgorithm.rsa2048:
        return 2048;
      case SshKeyAlgorithm.rsa3072:
        return 3072;
      case SshKeyAlgorithm.rsa4096:
        return 4096;
      default:
        return null;
    }
  }
}

/// A locally generated SSH key pair. Private keys are returned in a standard
/// format suitable for OpenSSH and are encrypted by the vault before storage.
class GeneratedSshKeyPair {
  final SshKeyAlgorithm algorithm;
  final String privateKey;
  final String publicKey;
  final String fingerprint;

  const GeneratedSshKeyPair({
    required this.algorithm,
    required this.privateKey,
    required this.publicKey,
    required this.fingerprint,
  });
}

class SshKeyService {
  static const int rsaBits = 3072;

  /// Generates a standards-compatible SSH key pair in a background isolate.
  static Future<GeneratedSshKeyPair> generateKeyPair({
    SshKeyAlgorithm algorithm = SshKeyAlgorithm.ed25519,
    String comment = 'passguard',
  }) async {
    final result = await compute(_generateSshKeyPair, {
      'algorithm': algorithm.name,
      'comment': _safeComment(comment),
    });
    return GeneratedSshKeyPair(
      algorithm: algorithm,
      privateKey: result['private_key']!,
      publicKey: result['public_key']!,
      fingerprint: result['fingerprint']!,
    );
  }

  /// Kept for callers that expect the original RSA-3072 generator.
  static Future<GeneratedSshKeyPair> generateRsaKeyPair({
    String comment = 'passguard',
  }) =>
      generateKeyPair(
        algorithm: SshKeyAlgorithm.rsa3072,
        comment: comment,
      );

  @visibleForTesting
  static Uint8List ed25519PublicKeyFromSeed(Uint8List seed) =>
      _ed25519PublicKey(seed);

  static String _safeComment(String comment) {
    final cleaned = comment.trim().replaceAll(RegExp(r'\s+'), '-');
    if (cleaned.isEmpty) return 'passguard';
    return cleaned.substring(0, cleaned.length > 80 ? 80 : cleaned.length);
  }
}

// Top-level function required by [compute].
Map<String, String> _generateSshKeyPair(Map<String, dynamic> arguments) {
  final algorithm = SshKeyAlgorithm.values.byName(
    arguments['algorithm'] as String,
  );
  final comment = arguments['comment'] as String;

  switch (algorithm) {
    case SshKeyAlgorithm.ed25519:
      return _generateEd25519KeyPair(comment);
    case SshKeyAlgorithm.rsa2048:
    case SshKeyAlgorithm.rsa3072:
    case SshKeyAlgorithm.rsa4096:
      return _generateRsaKeyPair(algorithm.rsaBits!, comment);
    case SshKeyAlgorithm.ecdsaP256:
    case SshKeyAlgorithm.ecdsaP384:
      return _generateEcdsaKeyPair(algorithm, comment);
  }
}

Map<String, String> _generateRsaKeyPair(int bits, String comment) {
  // Fortuna requires exactly 256 bits of seed material.
  final seed = EncryptionService.generateSecureRandomBytes(32);
  final random = FortunaRandom()..seed(KeyParameter(seed));
  final keyGenerator = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), bits, 64),
        random,
      ),
    );

  final pair = keyGenerator.generateKeyPair();
  final publicKey = pair.publicKey as RSAPublicKey;
  final privateKey = pair.privateKey as RSAPrivateKey;
  final publicBlob = _openSshRsaPublicBlob(publicKey);
  seed.fillRange(0, seed.length, 0);

  return _result(
    privateKey: _encodeRsaPrivateKeyPem(privateKey),
    publicBlob: publicBlob,
    comment: comment,
    keyType: 'ssh-rsa',
  );
}

Map<String, String> _generateEcdsaKeyPair(
  SshKeyAlgorithm algorithm,
  String comment,
) {
  final isP256 = algorithm == SshKeyAlgorithm.ecdsaP256;
  final domain = ECDomainParameters(isP256 ? 'prime256v1' : 'secp384r1');
  final seed = EncryptionService.generateSecureRandomBytes(32);
  final random = FortunaRandom()..seed(KeyParameter(seed));
  final generator = ECKeyGenerator()
    ..init(ParametersWithRandom(ECKeyGeneratorParameters(domain), random));
  final pair = generator.generateKeyPair();
  final publicKey = pair.publicKey as ECPublicKey;
  final privateKey = pair.privateKey as ECPrivateKey;
  final curve = isP256 ? 'nistp256' : 'nistp384';
  final keyType = 'ecdsa-sha2-$curve';
  final publicPoint = publicKey.Q!.getEncoded(false);
  final publicBlob = _concatBytes([
    _sshString(utf8.encode(keyType)),
    _sshString(utf8.encode(curve)),
    _sshString(publicPoint),
  ]);
  final privatePem = _encodeOpenSshPrivateKey(
    publicBlob: publicBlob,
    privateFields: [
      _sshString(utf8.encode(keyType)),
      _sshString(utf8.encode(curve)),
      _sshString(publicPoint),
      _sshMpint(privateKey.d!),
      _sshString(utf8.encode(comment)),
    ],
  );
  seed.fillRange(0, seed.length, 0);

  return _result(
    privateKey: privatePem,
    publicBlob: publicBlob,
    comment: comment,
    keyType: keyType,
  );
}

Map<String, String> _generateEd25519KeyPair(String comment) {
  final seed = EncryptionService.generateSecureRandomBytes(32);
  final publicKey = _ed25519PublicKey(seed);
  final publicBlob = _concatBytes([
    _sshString(utf8.encode('ssh-ed25519')),
    _sshString(publicKey),
  ]);
  final privateBytes = Uint8List(64)
    ..setAll(0, seed)
    ..setAll(32, publicKey);
  final privatePem = _encodeOpenSshPrivateKey(
    publicBlob: publicBlob,
    privateFields: [
      _sshString(utf8.encode('ssh-ed25519')),
      _sshString(publicKey),
      _sshString(privateBytes),
      _sshString(utf8.encode(comment)),
    ],
  );
  seed.fillRange(0, seed.length, 0);
  privateBytes.fillRange(0, privateBytes.length, 0);

  return _result(
    privateKey: privatePem,
    publicBlob: publicBlob,
    comment: comment,
    keyType: 'ssh-ed25519',
  );
}

Map<String, String> _result({
  required String privateKey,
  required Uint8List publicBlob,
  required String comment,
  required String keyType,
}) {
  return {
    'private_key': privateKey,
    'public_key': '$keyType ${base64Encode(publicBlob)} $comment',
    'fingerprint':
        'SHA256:${base64Encode(sha256.convert(publicBlob).bytes).replaceAll('=', '')}',
  };
}

Uint8List _openSshRsaPublicBlob(RSAPublicKey key) {
  return _concatBytes([
    _sshString(utf8.encode('ssh-rsa')),
    _sshMpint(key.publicExponent!),
    _sshMpint(key.modulus!),
  ]);
}

String _encodeOpenSshPrivateKey({
  required Uint8List publicBlob,
  required List<Uint8List> privateFields,
}) {
  final check = EncryptionService.generateSecureRandomBytes(4);
  var privateBlock = _concatBytes([
    check,
    check,
    ...privateFields,
  ]);
  final paddingLength = 8 - (privateBlock.length % 8);
  privateBlock = _concatBytes([
    privateBlock,
    Uint8List.fromList(
      List<int>.generate(paddingLength, (index) => index + 1),
    ),
  ]);
  check.fillRange(0, check.length, 0);

  final encoded = _concatBytes([
    Uint8List.fromList([...utf8.encode('openssh-key-v1'), 0]),
    _sshString(utf8.encode('none')),
    _sshString(utf8.encode('none')),
    _sshString(const []),
    _uint32(1),
    _sshString(publicBlob),
    _sshString(privateBlock),
  ]);
  privateBlock.fillRange(0, privateBlock.length, 0);
  return _pemEncode('OPENSSH PRIVATE KEY', encoded);
}

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
  return _pemEncode('RSA PRIVATE KEY', der);
}

String _pemEncode(String label, Uint8List der) {
  final encoded = base64Encode(der);
  final lines = <String>[
    '-----BEGIN $label-----',
    for (var index = 0; index < encoded.length; index += 64)
      encoded.substring(
        index,
        index + 64 > encoded.length ? encoded.length : index + 64,
      ),
    '-----END $label-----',
  ];
  // OpenSSH's PEM reader requires a terminal line break.
  return '${lines.join('\n')}\n';
}

Uint8List _sshString(List<int> value) => _concatBytes([
      _uint32(value.length),
      Uint8List.fromList(value),
    ]);

Uint8List _sshMpint(BigInt value) {
  var bytes = _unsignedBigInt(value);
  // SSH mpint values are signed two's-complement integers. Prefix a zero when
  // the high bit is set so a scalar/modulus is not parsed as a negative value.
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

Uint8List _derSequence(List<Uint8List> values) {
  final body = _concatBytes(values);
  return _concatBytes([
    Uint8List.fromList([0x30]),
    _derLength(body.length),
    body,
  ]);
}

Uint8List _derInteger(BigInt value) {
  var bytes = _unsignedBigInt(value);
  if (bytes.first & 0x80 != 0) {
    bytes = _concatBytes([
      Uint8List.fromList([0]),
      bytes
    ]);
  }
  return _concatBytes([
    Uint8List.fromList([0x02]),
    _derLength(bytes.length),
    bytes,
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

// ── RFC 8032 Ed25519 key generation ────────────────────────────────────────

final BigInt _edP = (BigInt.one << 255) - BigInt.from(19);
final BigInt _edD = _edMod(
  -BigInt.from(121665) * BigInt.from(121666).modInverse(_edP),
);
final _EdPoint _edBase = _EdPoint.fromAffine(
  BigInt.parse(
    '15112221349535400772501151409588531511454012693041857206046113283949847762202',
  ),
  BigInt.parse(
    '46316835694926478169428394003475163141307993866256225615783033603165251855960',
  ),
);

class _EdPoint {
  final BigInt x;
  final BigInt y;
  final BigInt z;
  final BigInt t;

  const _EdPoint(this.x, this.y, this.z, this.t);

  factory _EdPoint.fromAffine(BigInt x, BigInt y) =>
      _EdPoint(x, y, BigInt.one, _edMod(x * y));

  static final identity = _EdPoint(
    BigInt.zero,
    BigInt.one,
    BigInt.one,
    BigInt.zero,
  );

  _EdPoint add(_EdPoint other) {
    final a = _edMod((y - x) * (other.y - other.x));
    final b = _edMod((y + x) * (other.y + other.x));
    final c = _edMod(BigInt.two * _edD * t * other.t);
    final d = _edMod(BigInt.two * z * other.z);
    final e = _edMod(b - a);
    final f = _edMod(d - c);
    final g = _edMod(d + c);
    final h = _edMod(b + a);
    return _EdPoint(
      _edMod(e * f),
      _edMod(g * h),
      _edMod(f * g),
      _edMod(e * h),
    );
  }

  _EdPoint doubled() {
    final a = _edMod(x * x);
    final b = _edMod(y * y);
    final c = _edMod(BigInt.two * z * z);
    final d = _edMod(-a);
    final e = _edMod((x + y) * (x + y) - a - b);
    final g = _edMod(d + b);
    final f = _edMod(g - c);
    final h = _edMod(d - b);
    return _EdPoint(
      _edMod(e * f),
      _edMod(g * h),
      _edMod(f * g),
      _edMod(e * h),
    );
  }

  Uint8List encode() {
    final inverseZ = z.modInverse(_edP);
    final affineX = _edMod(x * inverseZ);
    final affineY = _edMod(y * inverseZ);
    final result = _littleEndian(affineY, 32);
    if (affineX.isOdd) result[31] |= 0x80;
    return result;
  }
}

BigInt _edMod(BigInt value) {
  final remainder = value % _edP;
  return remainder.isNegative ? remainder + _edP : remainder;
}

Uint8List _ed25519PublicKey(Uint8List seed) {
  final digest = Uint8List.fromList(sha512.convert(seed).bytes);
  digest[0] &= 248;
  digest[31] &= 63;
  digest[31] |= 64;
  final scalar = _littleEndianToBigInt(digest.sublist(0, 32));
  digest.fillRange(0, digest.length, 0);
  return _edScalarMultiply(scalar).encode();
}

_EdPoint _edScalarMultiply(BigInt scalar) {
  var result = _EdPoint.identity;
  var point = _edBase;
  var remaining = scalar;
  while (remaining > BigInt.zero) {
    if (remaining.isOdd) result = result.add(point);
    point = point.doubled();
    remaining >>= 1;
  }
  return result;
}

Uint8List _littleEndian(BigInt value, int length) {
  final bytes = Uint8List(length);
  var remaining = value;
  for (var index = 0; index < length; index++) {
    bytes[index] = (remaining & BigInt.from(0xff)).toInt();
    remaining >>= 8;
  }
  return bytes;
}

BigInt _littleEndianToBigInt(List<int> bytes) {
  var value = BigInt.zero;
  for (var index = bytes.length - 1; index >= 0; index--) {
    value = (value << 8) | BigInt.from(bytes[index]);
  }
  return value;
}
