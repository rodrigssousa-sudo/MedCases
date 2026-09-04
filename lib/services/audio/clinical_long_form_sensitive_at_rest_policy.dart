enum ClinicalLongFormSensitiveAssetKind {
  activeAudioSegment,
  closedAudioSegment,
  recordingManifest,
  batchQueue,
  segmentTranscriptCheckpoint,
  reviewedTranscript,
  retentionMetadata,
  transportPlaintextStaging,
}

enum ClinicalLongFormIosFileProtectionProfile { completeUnlessOpen, complete }

enum ClinicalLongFormAndroidStorageProfile { noBackupFilesDir }

final class ClinicalLongFormSensitiveAtRestRule {
  const ClinicalLongFormSensitiveAtRestRule({
    required this.kind,
    required this.backupExcluded,
    required this.automaticCloudSyncAllowed,
    required this.iosFileProtection,
    required this.androidStorage,
    required this.applicationLayerEncryptionRequired,
    required this.encryptImmediatelyAfterClose,
    required this.deleteAfterUseRequired,
    required this.maximumPlaintextLifetimeSeconds,
  });

  final ClinicalLongFormSensitiveAssetKind kind;
  final bool backupExcluded;
  final bool automaticCloudSyncAllowed;
  final ClinicalLongFormIosFileProtectionProfile iosFileProtection;
  final ClinicalLongFormAndroidStorageProfile androidStorage;
  final bool applicationLayerEncryptionRequired;
  final bool encryptImmediatelyAfterClose;
  final bool deleteAfterUseRequired;
  final int? maximumPlaintextLifetimeSeconds;
}

final class ClinicalLongFormSensitiveAtRestPolicy {
  const ClinicalLongFormSensitiveAtRestPolicy._();

  static const bool productionPersistenceIntegrationEnabled = false;
  static const bool nativePlatformEnforcementImplemented = false;
  static const bool backupAllowedByDefault = false;
  static const bool automaticCloudSyncAllowed = false;
  static const bool patientIdentityAllowedInFileNames = false;
  static const bool opaqueSessionIdRequired = true;

  static const String applicationLayerCipher = 'AES-256-GCM';
  static const bool associatedDataBindingRequired = true;
  static const bool uniqueNoncePerEncryptionRequired = true;

  static const String iosKeyStore = 'Keychain';
  static const String iosKeyAccessibility = 'whenUnlockedThisDeviceOnly';
  static const String androidKeyStore = 'AndroidKeystore';
  static const bool androidHardwareBackedKeyPreferred = true;

  static const bool keyExportAllowed = false;
  static const bool keyBackupAllowed = false;
  static const bool reviewedTranscriptBackupAllowed = false;
  static const bool explicitUserExportIsSeparateFlow = true;
  static const int transportPlaintextMaximumLifetimeSeconds = 120;

  static ClinicalLongFormSensitiveAtRestRule ruleFor(
    ClinicalLongFormSensitiveAssetKind kind,
  ) {
    if (kind == ClinicalLongFormSensitiveAssetKind.activeAudioSegment) {
      return const ClinicalLongFormSensitiveAtRestRule(
        kind: ClinicalLongFormSensitiveAssetKind.activeAudioSegment,
        backupExcluded: true,
        automaticCloudSyncAllowed: false,
        iosFileProtection:
            ClinicalLongFormIosFileProtectionProfile.completeUnlessOpen,
        androidStorage: ClinicalLongFormAndroidStorageProfile.noBackupFilesDir,
        applicationLayerEncryptionRequired: false,
        encryptImmediatelyAfterClose: true,
        deleteAfterUseRequired: false,
        maximumPlaintextLifetimeSeconds: null,
      );
    }

    if (kind == ClinicalLongFormSensitiveAssetKind.transportPlaintextStaging) {
      return const ClinicalLongFormSensitiveAtRestRule(
        kind: ClinicalLongFormSensitiveAssetKind.transportPlaintextStaging,
        backupExcluded: true,
        automaticCloudSyncAllowed: false,
        iosFileProtection: ClinicalLongFormIosFileProtectionProfile.complete,
        androidStorage: ClinicalLongFormAndroidStorageProfile.noBackupFilesDir,
        applicationLayerEncryptionRequired: false,
        encryptImmediatelyAfterClose: false,
        deleteAfterUseRequired: true,
        maximumPlaintextLifetimeSeconds:
            transportPlaintextMaximumLifetimeSeconds,
      );
    }

    return ClinicalLongFormSensitiveAtRestRule(
      kind: kind,
      backupExcluded: true,
      automaticCloudSyncAllowed: false,
      iosFileProtection: ClinicalLongFormIosFileProtectionProfile.complete,
      androidStorage: ClinicalLongFormAndroidStorageProfile.noBackupFilesDir,
      applicationLayerEncryptionRequired: true,
      encryptImmediatelyAfterClose:
          kind == ClinicalLongFormSensitiveAssetKind.closedAudioSegment,
      deleteAfterUseRequired: false,
      maximumPlaintextLifetimeSeconds: null,
    );
  }
}

final class ClinicalLongFormSensitiveAssetDescriptor {
  ClinicalLongFormSensitiveAssetDescriptor({
    required this.sessionId,
    required this.kind,
    required this.logicalName,
  }) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(sessionId)) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    if (!RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(logicalName)) {
      throw ArgumentError.value(logicalName, 'logicalName');
    }
  }

  final String sessionId;
  final ClinicalLongFormSensitiveAssetKind kind;
  final String logicalName;
}
