import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pointycastle/asymmetric/api.dart' as pc_api;
import 'package:pointycastle/pointycastle.dart'; // Replaces specific imports

/// Service managing End-to-End Encryption (E2EE)
/// Handles Key Generation (RSA), Key Storage, and Message Encryption (AES+RSA).
class E2EEncryptionService {
  static final _storage = const FlutterSecureStorage();
  static final _db = FirebaseFirestore.instance;

  // --- 1. KEY MANAGEMENT ---

  /// Generate a fresh RSA Key Pair (2048-bit)
  /// Returns { 'private': PEM_STRING, 'public': PEM_STRING }
  static Future<Map<String, String>> generateKeyPair() async {
    return await compute(_generateRSAKeyPair, 2048);
  }

  /// Background isolate for heavy RSA generation
  static Map<String, String> _generateRSAKeyPair(int bitLength) {
    final secureRandom = pc.FortunaRandom();
    final seed = Uint8List(32);
    final random = Random.secure();
    for (int i = 0; i < 32; i++) seed[i] = random.nextInt(255);
    secureRandom.seed(pc.KeyParameter(seed));

    final keyGen = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64),
        secureRandom,
      ));

    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as pc_api.RSAPublicKey;
    final privateKey = pair.privateKey as pc_api.RSAPrivateKey;

    return {
      'public': _encodePublicKeyToPem(publicKey),
      'private': _encodePrivateKeyToPem(privateKey),
    };
  }

  /// Save keys: Private -> Local Secure Storage, Public -> Firestore
  static Future<void> saveKeys(String userId, Map<String, String> keys) async {
    // 1. Save Private Key Locally
    await _storage.write(key: 'private_key_$userId', value: keys['private']);
    
    // 2. Publish Public Key to Firestore
    await _db.collection('users').doc(userId).collection('keys').doc('master').set({
      'publicKey': keys['public'],
      'createdAt': FieldValue.serverTimestamp(),
      'version': 1,
    });
  }

  /// Retrieve Local Private Key
  static Future<String?> getPrivateKey(String userId) async {
    return await _storage.read(key: 'private_key_$userId');
  }

  /// Fetch Remote Public Key (Friend)
  static Future<String?> getPublicKey(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).collection('keys').doc('master').get();
      if (doc.exists) {
        return doc.data()?['publicKey'];
      }
    } catch (e) {
      debugPrint('Error fetching public key for $userId: $e');
    }
    return null;
  }

  /// Ensure user has keys (Call on Login/Home)
  static Future<void> ensureKeysExist(String userId) async {
    final hasKey = await _storage.containsKey(key: 'private_key_$userId');
    if (!hasKey) {
      debugPrint('[ENCRYPTION] Generating new keys for $userId...');
      final keys = await generateKeyPair();
      await saveKeys(userId, keys);
      debugPrint('[ENCRYPTION] Keys generated and saved.');
    }
  }

  // --- 2. ENCRYPTION (AES + RSA) ---

  /// Encrypts for Recipient AND Sender (so Sender can read it back)
  static Future<Map<String, dynamic>> encryptMessageDual(String plainText, String recipientPublicKeyPem, String senderPublicKeyPem) async {
    // 1. Generate ephemeral AES Key and IV
    final aesKey = enc.Key.fromSecureRandom(32);
    final iv = enc.IV.fromSecureRandom(16);

    // 2. Encrypt Content with AES
    final encrypter = enc.Encrypter(enc.AES(aesKey));
    final encryptedContent = encrypter.encrypt(plainText, iv: iv);

    // 3. Encrypt AES Key with Recipient's RSA Public Key
    final parser = enc.RSAKeyParser();
    final rsaPublicRecip = parser.parse(recipientPublicKeyPem) as pc_api.RSAPublicKey;
    final rsaEncrypterRecip = enc.Encrypter(enc.RSA(publicKey: rsaPublicRecip));
    final encryptedKeyRecip = rsaEncrypterRecip.encryptBytes(aesKey.bytes);
    
    // 4. Encrypt AES Key with Sender's RSA Public Key
    final rsaPublicSender = parser.parse(senderPublicKeyPem) as pc_api.RSAPublicKey;
    final rsaEncrypterSender = enc.Encrypter(enc.RSA(publicKey: rsaPublicSender));
    final encryptedKeySender = rsaEncrypterSender.encryptBytes(aesKey.bytes);

    return {
      'content': encryptedContent.base64,
      'key': base64Encode(encryptedKeyRecip.bytes),
      'keySender': base64Encode(encryptedKeySender.bytes),
      'iv': iv.base64,
    };
  }

  /// Encrypts a message for a specific recipient
  /// Returns { 'content': AES_ENCRYPTED_TEXT, 'key': RSA_ENCRYPTED_AES_KEY, 'iv': IV }
  static Future<Map<String, String>> encryptMessage(String plainText, String recipientPublicKeyPem) async {
    // 1. Generate ephemeral AES Key and IV
    final aesKey = enc.Key.fromSecureRandom(32);
    final iv = enc.IV.fromSecureRandom(16);

    // 2. Encrypt Content with AES
    final encrypter = enc.Encrypter(enc.AES(aesKey));
    final encryptedContent = encrypter.encrypt(plainText, iv: iv);

    // 3. Encrypt AES Key with Recipient's RSA Public Key
    final parser = enc.RSAKeyParser();
    final rsaPublicKey = parser.parse(recipientPublicKeyPem) as pc_api.RSAPublicKey;
    final rsaEncrypter = enc.Encrypter(enc.RSA(publicKey: rsaPublicKey));
    final encryptedKey = rsaEncrypter.encryptBytes(aesKey.bytes);

    return {
      'content': encryptedContent.base64,
      'key': base64Encode(encryptedKey.bytes),
      'iv': iv.base64,
    };
  }

  /// Decrypts a message using my Private Key
  static Future<String> decryptMessage(Map<String, dynamic> payload, String myPrivateKeyPem) async {
    try {
      // 1. Parse payload
      final encryptedContentBase64 = payload['content']; // The message text
      final encryptedKeyBase64 = payload['key']; // The AES key
      final ivBase64 = payload['iv'];

      // 2. Decrypt AES Key with My RSA Private Key
      final parser = enc.RSAKeyParser();
      final rsaPrivateKey = parser.parse(myPrivateKeyPem) as pc_api.RSAPrivateKey;
      final rsaEncrypter = enc.Encrypter(enc.RSA(privateKey: rsaPrivateKey));
      
      final aesKeyBytes = rsaEncrypter.decryptBytes(enc.Encrypted(base64Decode(encryptedKeyBase64)));
      final aesKey = enc.Key(Uint8List.fromList(aesKeyBytes));
      final iv = enc.IV.fromBase64(ivBase64);

      // 3. Decrypt Content with AES
      final encrypter = enc.Encrypter(enc.AES(aesKey));
      final decrypted = encrypter.decrypt(enc.Encrypted.fromBase64(encryptedContentBase64), iv: iv);

      return decrypted;
    } catch (e) {
      debugPrint('Error decrypting message: $e');
      return '[Message illisible - Erreur de déchiffrement]';
    }
  }

  // --- HELPERS (PEM Encoding) ---
  
  static String _encodePublicKeyToPem(pc_api.RSAPublicKey publicKey) {
    // Basic PEM encoding using manual ASN.1 construction
    var algorithmSeq = ASN1Sequence();
    var params = ASN1Sequence();
    params.add(ASN1ObjectIdentifier.fromName('rsaEncryption'));
    params.add(ASN1Null());
    algorithmSeq.add(params);

    var publicKeySeq = ASN1Sequence();
    publicKeySeq.add(ASN1Integer(publicKey.modulus));
    publicKeySeq.add(ASN1Integer(publicKey.exponent));
    var publicKeySeqBitString = ASN1BitString(stringValues: Uint8List.fromList(publicKeySeq.encode()));

    var topLevelSeq = ASN1Sequence();
    topLevelSeq.add(algorithmSeq);
    topLevelSeq.add(publicKeySeqBitString);

    var dataBase64 = base64.encode(topLevelSeq.encode());
    return """-----BEGIN PUBLIC KEY-----
$dataBase64
-----END PUBLIC KEY-----""";
  }

  static String _encodePrivateKeyToPem(pc_api.RSAPrivateKey privateKey) {
    var version = ASN1Integer(BigInt.zero);
    var modulus = ASN1Integer(privateKey.modulus);
    var publicExponent = ASN1Integer(privateKey.publicExponent); // Usually 65537
    var privateExponent = ASN1Integer(privateKey.privateExponent);
    var p = ASN1Integer(privateKey.p);
    var q = ASN1Integer(privateKey.q);
    var dP = ASN1Integer(privateKey.privateExponent! % (privateKey.p! - BigInt.one));
    var dQ = ASN1Integer(privateKey.privateExponent! % (privateKey.q! - BigInt.one));
    var qInv = ASN1Integer(privateKey.q!.modInverse(privateKey.p!));

    var seq = ASN1Sequence();
    seq.add(version);
    seq.add(modulus);
    seq.add(publicExponent);
    seq.add(privateExponent);
    seq.add(p);
    seq.add(q);
    seq.add(dP);
    seq.add(dQ);
     seq.add(qInv);

    var dataBase64 = base64.encode(seq.encode());
    return """-----BEGIN RSA PRIVATE KEY-----
$dataBase64
-----END RSA PRIVATE KEY-----""";
  }
}
