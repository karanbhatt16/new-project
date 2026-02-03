import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Passphrase-based encrypted backup for a 32-byte X25519 seed.
///
/// Format stored in Firestore:
/// {
///   kdf: 'pbkdf2-sha256',
///   iterations: 200000,
///   saltB64: ...,   // 16 bytes
///   nonceB64: ...,  // 12 bytes
///   ciphertextB64: ..., // encrypted seed bytes
///   macB64: ...,
/// }
class KeyBackup {
  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int keyLength = 32; // AES-256

  static const int defaultIterations = 200000;

  static Future<Map<String, dynamic>> encryptSeed({
    required List<int> seed32,
    required String passphrase,
    int iterations = defaultIterations,
  }) async {
    if (seed32.length != 32) {
      throw ArgumentError('seed must be 32 bytes');
    }

    final random = kIsWeb ? Random() : Random.secure();
    final salt = List<int>.generate(saltLength, (_) => random.nextInt(256), growable: false);

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: keyLength * 8,
    );

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );

    final aes = AesGcm.with256bits();
    final nonce = List<int>.generate(nonceLength, (_) => random.nextInt(256), growable: false);

    final box = await aes.encrypt(
      seed32,
      secretKey: secretKey,
      nonce: nonce,
      aad: utf8.encode('vibeu:key-backup:v1'),
    );

    return {
      'kdf': 'pbkdf2-sha256',
      'iterations': iterations,
      'saltB64': base64Encode(salt),
      'nonceB64': base64Encode(nonce),
      'ciphertextB64': base64Encode(box.cipherText),
      'macB64': base64Encode(box.mac.bytes),
    };
  }

  static Future<List<int>> decryptSeed({
    required Map<String, dynamic> backup,
    required String passphrase,
  }) async {
    final iterations = (backup['iterations'] as int?) ?? defaultIterations;
    final salt = base64Decode(backup['saltB64'] as String);
    final nonce = base64Decode(backup['nonceB64'] as String);
    final ciphertext = base64Decode(backup['ciphertextB64'] as String);
    final mac = Mac(base64Decode(backup['macB64'] as String));

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: keyLength * 8,
    );

    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );

    final aes = AesGcm.with256bits();
    final box = SecretBox(ciphertext, nonce: nonce, mac: mac);

    final seed = await aes.decrypt(
      box,
      secretKey: secretKey,
      aad: utf8.encode('vibeu:key-backup:v1'),
    );

    if (seed.length != 32) {
      throw StateError('Decrypted seed is not 32 bytes');
    }

    return seed;
  }
}
