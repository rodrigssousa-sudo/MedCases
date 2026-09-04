import 'package:cryptography/cryptography.dart';

final class ClinicalLongFormAtRestKeyMaterial {
  ClinicalLongFormAtRestKeyMaterial({
    required this.keyId,
    required this.secretKey,
  }) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(keyId)) {
      throw ArgumentError.value(keyId, 'keyId');
    }
  }

  final String keyId;
  final SecretKey secretKey;
}

abstract interface class ClinicalLongFormAtRestKeyProvider {
  Future<ClinicalLongFormAtRestKeyMaterial> currentEncryptionKey();
  Future<SecretKey> keyForId(String keyId);
}

final class ClinicalLongFormAtRestKeyManagementPolicy {
  const ClinicalLongFormAtRestKeyManagementPolicy._();

  static const bool hardcodedSecretAllowed = false;
  static const bool keyExportAllowed = false;
  static const bool keyBackupAllowed = false;
  static const bool persistentKeyInDartFileAllowed = false;

  static const String iosStore = 'Keychain';
  static const String iosAccessibility = 'whenUnlockedThisDeviceOnly';
  static const String androidStore = 'AndroidKeystore';

  static const bool nativeProviderImplemented = false;
  static const bool productionCutoverEnabled = false;
}
