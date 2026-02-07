import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../auth/firebase_auth_controller.dart';
import 'firestore_chat_controller.dart';
import 'firestore_chat_models.dart';

/// Simple E2EE wrapper for chat operations.
///
/// Uses a single app-wide encryption key for all messages.
/// Messages are encrypted with AES-256-GCM before storing in Firebase
/// and decrypted when received.
class E2eeChatController extends ChangeNotifier {
  E2eeChatController({
    required this.auth,
    required this.chat,
  });

  final FirebaseAuthController auth;
  final FirestoreChatController chat;

  /// The AES-256-GCM cipher
  final _aes = AesGcm.with256bits();

  /// App-wide encryption key (32 bytes for AES-256)
  /// In production, you might want to store this more securely or derive it
  static final _appKey = SecretKey(utf8.encode('VibeU_Secret_Key_2024_32_Bytes!!')); // Exactly 32 bytes

  /// Encrypt a plaintext string using the app-wide key.
  /// Returns a map with ciphertextB64, nonceB64, and macB64.
  Future<Map<String, String>> _encrypt(String plaintext) async {
    final nonce = _aes.newNonce(); // Random 12-byte nonce
    final secretBox = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: _appKey,
      nonce: nonce,
    );

    return {
      'ciphertextB64': base64Encode(secretBox.cipherText),
      'nonceB64': base64Encode(secretBox.nonce),
      'macB64': base64Encode(secretBox.mac.bytes),
    };
  }

  /// Decrypt a message using the app-wide key.
  /// Returns the plaintext string or null if decryption fails.
  Future<String?> _decrypt({
    required String ciphertextB64,
    required String nonceB64,
    required String macB64,
  }) async {
    try {
      final cipherText = base64Decode(ciphertextB64);
      final nonce = base64Decode(nonceB64);
      final mac = Mac(base64Decode(macB64));

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
      final plainBytes = await _aes.decrypt(secretBox, secretKey: _appKey);

      return utf8.decode(plainBytes);
    } catch (e) {
      debugPrint('E2EE: Decryption failed: $e');
      return null;
    }
  }

  /// Send an encrypted text message.
  ///
  /// The message is encrypted with AES-256-GCM using the app-wide key.
  /// Returns the message ID.
  Future<String> sendEncryptedMessage({
    required String threadId,
    required String fromUid,
    required String fromEmail,
    required String toUid,
    required String toEmail,
    required String text,
    String? replyToMessageId,
    String? replyToFromUid,
    String? replyToText,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('text is empty');
    }

    // Encrypt the message
    final encrypted = await _encrypt(trimmed);

    // Also encrypt reply text if present
    String? encryptedReplyText;
    if (replyToText != null && replyToText.isNotEmpty) {
      final encryptedReply = await _encrypt(replyToText);
      encryptedReplyText = jsonEncode(encryptedReply);
    }

    // Send encrypted message via the base controller
    return chat.sendEncryptedMessage(
      threadId: threadId,
      fromUid: fromUid,
      toUid: toUid,
      ciphertextB64: encrypted['ciphertextB64']!,
      nonceB64: encrypted['nonceB64']!,
      macB64: encrypted['macB64']!,
      replyToMessageId: replyToMessageId,
      replyToFromUid: replyToFromUid,
      replyToTextEncrypted: encryptedReplyText,
    );
  }

  /// Send an encrypted voice message.
  ///
  /// The voice URL is encrypted to prevent metadata leakage.
  Future<String> sendEncryptedVoiceMessage({
    required String threadId,
    required String fromUid,
    required String toUid,
    required String voiceUrl,
    required int durationSeconds,
    String? replyToMessageId,
    String? replyToFromUid,
    String? replyToText,
  }) async {
    // Encrypt the voice URL
    final encrypted = await _encrypt(voiceUrl);

    // Encrypt reply text if present
    String? encryptedReplyText;
    if (replyToText != null && replyToText.isNotEmpty) {
      final encryptedReply = await _encrypt(replyToText);
      encryptedReplyText = jsonEncode(encryptedReply);
    }

    return chat.sendEncryptedVoiceMessage(
      threadId: threadId,
      fromUid: fromUid,
      toUid: toUid,
      voiceUrlCiphertextB64: encrypted['ciphertextB64']!,
      voiceUrlNonceB64: encrypted['nonceB64']!,
      voiceUrlMacB64: encrypted['macB64']!,
      durationSeconds: durationSeconds,
      replyToMessageId: replyToMessageId,
      replyToFromUid: replyToFromUid,
      replyToTextEncrypted: encryptedReplyText,
    );
  }

  /// Decrypt a message's text content.
  ///
  /// Returns null if decryption fails or message is not encrypted.
  Future<String?> decryptMessage(FirestoreMessage message) async {
    if (message.ciphertextB64 == null ||
        message.nonceB64 == null ||
        message.macB64 == null) {
      return null;
    }

    return _decrypt(
      ciphertextB64: message.ciphertextB64!,
      nonceB64: message.nonceB64!,
      macB64: message.macB64!,
    );
  }

  /// Decrypt a voice message URL.
  Future<String?> decryptVoiceUrl(FirestoreMessage message) async {
    if (message.voiceUrlCiphertextB64 == null ||
        message.voiceUrlNonceB64 == null ||
        message.voiceUrlMacB64 == null) {
      return message.voiceUrl; // Return plaintext URL if available
    }

    return _decrypt(
      ciphertextB64: message.voiceUrlCiphertextB64!,
      nonceB64: message.voiceUrlNonceB64!,
      macB64: message.voiceUrlMacB64!,
    );
  }

  /// Decrypt reply text from an encrypted message.
  Future<String?> decryptReplyText(FirestoreMessage message) async {
    if (message.replyToTextEncrypted == null) {
      return message.replyToText; // Return plaintext if available
    }

    try {
      final encryptedData = jsonDecode(message.replyToTextEncrypted!) as Map<String, dynamic>;
      return _decrypt(
        ciphertextB64: encryptedData['ciphertextB64'] as String,
        nonceB64: encryptedData['nonceB64'] as String,
        macB64: encryptedData['macB64'] as String,
      );
    } catch (e) {
      debugPrint('E2EE: Failed to decrypt reply text: $e');
      return null;
    }
  }

  /// Cache for already-decrypted message texts: messageId -> decrypted text
  final Map<String, String> _decryptedMessageCache = {};

  /// Stream of messages with decrypted text populated.
  /// 
  /// This decrypts messages as they arrive from Firestore and caches the result.
  Stream<List<FirestoreMessage>> decryptedMessagesStream({
    required String threadId,
    required String otherUid,
  }) {
    return chat.messagesStream(threadId: threadId).asyncMap((messages) async {
      final result = <FirestoreMessage>[];
      
      for (final m in messages) {
        // If already has plaintext or is not encrypted, keep as-is
        if (m.text != null || m.ciphertextB64 == null) {
          result.add(m);
          continue;
        }
        
        // Check cache first
        if (_decryptedMessageCache.containsKey(m.id)) {
          result.add(_withDecryptedText(m, _decryptedMessageCache[m.id]!));
          continue;
        }
        
        // Decrypt the message using the simple app-wide key
        final decrypted = await decryptMessage(m);
        if (decrypted != null) {
          _decryptedMessageCache[m.id] = decrypted;
          result.add(_withDecryptedText(m, decrypted));
        } else {
          result.add(m); // Keep encrypted message as-is if decryption fails
        }
      }
      
      return result;
    });
  }

  /// Create a copy of the message with decrypted text set.
  FirestoreMessage _withDecryptedText(FirestoreMessage m, String text) {
    return FirestoreMessage(
      id: m.id,
      threadId: m.threadId,
      fromUid: m.fromUid,
      toUid: m.toUid,
      sentAt: m.sentAt,
      text: text, // Set decrypted text here
      ciphertextB64: null, // Clear encrypted fields since we have plaintext now
      nonceB64: null,
      macB64: null,
      replyToMessageId: m.replyToMessageId,
      replyToFromUid: m.replyToFromUid,
      replyToText: m.replyToText,
      replyToTextEncrypted: m.replyToTextEncrypted,
      reactions: m.reactions,
      messageType: m.messageType,
      callDurationSeconds: m.callDurationSeconds,
      callStatus: m.callStatus,
      deletedForEveryone: m.deletedForEveryone,
      deletedForUsers: m.deletedForUsers,
      voiceUrl: m.voiceUrl,
      voiceDurationSeconds: m.voiceDurationSeconds,
      voiceUrlCiphertextB64: m.voiceUrlCiphertextB64,
      voiceUrlNonceB64: m.voiceUrlNonceB64,
      voiceUrlMacB64: m.voiceUrlMacB64,
    );
  }

  /// Clear cached messages (call on sign out)
  void clearCache() {
    _decryptedMessageCache.clear();
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}
