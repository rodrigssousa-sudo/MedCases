import 'dart:io';
import 'package:flutter/services.dart';

import 'clinical_long_form_sensitive_at_rest_policy.dart';

final class ClinicalLongFormNativeAtRestCapabilities {
  const ClinicalLongFormNativeAtRestCapabilities({
    required this.platform,
    required this.secureRootKind,
    required this.keyStore,
    required this.cipher,
    required this.keyExportToFlutter,
    required this.productionIntegrationEnabled,
  });

  final String platform;
  final String secureRootKind;
  final String keyStore;
  final String cipher;
  final bool keyExportToFlutter;
  final bool productionIntegrationEnabled;
}

final class ClinicalLongFormNativeFileCryptoResult {
  const ClinicalLongFormNativeFileCryptoResult({
    required this.path,
    required this.byteCount,
  });

  final String path;
  final int byteCount;
}

final class ClinicalLongFormNativeAtRestPlatformBridge {
  ClinicalLongFormNativeAtRestPlatformBridge({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'medcases/audio_at_rest_v2';

  static const bool productionPersistenceIntegrationEnabled = false;
  static const bool productionCutoverEnabled = false;
  static const bool keyMaterialMayCrossIntoFlutter = false;
  static const bool nativeAes256GcmImplemented = true;
  static const bool nativeNoBackupRootImplemented = true;
  static const bool nativeFileToFileCryptoImplemented = true;

  final MethodChannel _channel;

  Future<ClinicalLongFormNativeAtRestCapabilities> capabilities() async {
    final map = await _channel.invokeMapMethod<String, Object?>(
      'capabilities',
    );

    if (map == null) {
      throw StateError('Native at-rest capabilities unavailable.');
    }

    String string(String key) {
      final value = map[key];
      if (value is! String || value.trim().isEmpty) {
        throw StateError('Native capability $key invalid.');
      }
      return value;
    }

    bool boolean(String key) {
      final value = map[key];
      if (value is! bool) {
        throw StateError('Native capability $key invalid.');
      }
      return value;
    }

    final capabilities = ClinicalLongFormNativeAtRestCapabilities(
      platform: string('platform'),
      secureRootKind: string('secureRootKind'),
      keyStore: string('keyStore'),
      cipher: string('cipher'),
      keyExportToFlutter: boolean('keyExportToFlutter'),
      productionIntegrationEnabled: boolean('productionIntegrationEnabled'),
    );

    if (capabilities.keyExportToFlutter ||
        capabilities.productionIntegrationEnabled ||
        capabilities.cipher != 'AES-256-GCM') {
      throw StateError('Native at-rest security contract rejected.');
    }

    return capabilities;
  }

  Future<Directory> secureRootDirectory() async {
    final path = await _channel.invokeMethod<String>('secureRoot');

    if (path == null || path.trim().isEmpty) {
      throw StateError('Native secure root unavailable.');
    }

    return Directory(path);
  }

  Future<void> protectActiveAudioFile(String path) async {
    _validatePath(path);
    await _channel.invokeMethod<void>(
      'protectActiveAudioFile',
      <String, Object?>{'path': path},
    );
  }

  Future<void> protectDurableFile(String path) async {
    _validatePath(path);
    await _channel.invokeMethod<void>(
      'protectDurableFile',
      <String, Object?>{'path': path},
    );
  }

  Future<Uint8List> seal({
    required String keyId,
    required ClinicalLongFormSensitiveAssetDescriptor descriptor,
    required Uint8List clearText,
  }) async {
    _validateKeyId(keyId);

    final rule = ClinicalLongFormSensitiveAtRestPolicy.ruleFor(descriptor.kind);

    if (!rule.applicationLayerEncryptionRequired) {
      throw StateError(
        'Asset kind is not eligible for native durable encryption.',
      );
    }

    final sealed = await _channel.invokeMethod<Uint8List>(
      'seal',
      <String, Object?>{
        'keyId': keyId,
        'sessionId': descriptor.sessionId,
        'assetKind': descriptor.kind.name,
        'logicalName': descriptor.logicalName,
        'clearText': clearText,
      },
    );

    if (sealed == null || sealed.length <= 28) {
      throw StateError('Native sealed payload invalid.');
    }

    return sealed;
  }

  Future<Uint8List> open({
    required String keyId,
    required ClinicalLongFormSensitiveAssetDescriptor descriptor,
    required Uint8List sealedData,
  }) async {
    _validateKeyId(keyId);

    final rule = ClinicalLongFormSensitiveAtRestPolicy.ruleFor(descriptor.kind);

    if (!rule.applicationLayerEncryptionRequired) {
      throw StateError(
        'Asset kind is not eligible for native durable decryption.',
      );
    }

    if (sealedData.length <= 28) {
      throw ArgumentError.value(
        sealedData.length,
        'sealedData.length',
      );
    }

    final clear = await _channel.invokeMethod<Uint8List>(
      'open',
      <String, Object?>{
        'keyId': keyId,
        'sessionId': descriptor.sessionId,
        'assetKind': descriptor.kind.name,
        'logicalName': descriptor.logicalName,
        'sealedData': sealedData,
      },
    );

    if (clear == null) {
      throw StateError('Native plaintext unavailable.');
    }

    return clear;
  }

  Future<ClinicalLongFormNativeFileCryptoResult> sealFile({
    required String keyId,
    required ClinicalLongFormSensitiveAssetDescriptor descriptor,
    required String sourcePath,
    required String destinationPath,
  }) async {
    _validateKeyId(keyId);
    _validateClosedAudioDescriptor(descriptor);
    _validateDistinctPaths(
      sourcePath: sourcePath,
      destinationPath: destinationPath,
    );

    final result = await _channel.invokeMapMethod<String, Object?>(
      'sealFile',
      <String, Object?>{
        'keyId': keyId,
        'sessionId': descriptor.sessionId,
        'assetKind': descriptor.kind.name,
        'logicalName': descriptor.logicalName,
        'sourcePath': sourcePath,
        'destinationPath': destinationPath,
      },
    );

    return _parseFileCryptoResult(
      result,
      expectedDestinationPath: destinationPath,
    );
  }

  Future<ClinicalLongFormNativeFileCryptoResult> openFile({
    required String keyId,
    required ClinicalLongFormSensitiveAssetDescriptor descriptor,
    required String sourcePath,
    required String destinationPath,
  }) async {
    _validateKeyId(keyId);
    _validateClosedAudioDescriptor(descriptor);
    _validateDistinctPaths(
      sourcePath: sourcePath,
      destinationPath: destinationPath,
    );

    final result = await _channel.invokeMapMethod<String, Object?>(
      'openFile',
      <String, Object?>{
        'keyId': keyId,
        'sessionId': descriptor.sessionId,
        'assetKind': descriptor.kind.name,
        'logicalName': descriptor.logicalName,
        'sourcePath': sourcePath,
        'destinationPath': destinationPath,
      },
    );

    return _parseFileCryptoResult(
      result,
      expectedDestinationPath: destinationPath,
    );
  }

  static ClinicalLongFormNativeFileCryptoResult _parseFileCryptoResult(
    Map<String, Object?>? result, {
    required String expectedDestinationPath,
  }) {
    if (result == null) {
      throw StateError('Native file crypto result unavailable.');
    }

    final path = result['path'];
    final byteCount = result['byteCount'];

    if (path is! String ||
        path != expectedDestinationPath ||
        byteCount is! int ||
        byteCount < 1) {
      throw StateError('Native file crypto result invalid.');
    }

    return ClinicalLongFormNativeFileCryptoResult(
      path: path,
      byteCount: byteCount,
    );
  }

  static void _validateClosedAudioDescriptor(
    ClinicalLongFormSensitiveAssetDescriptor descriptor,
  ) {
    if (descriptor.kind !=
        ClinicalLongFormSensitiveAssetKind.closedAudioSegment) {
      throw StateError(
        'Native file-to-file crypto is restricted to closed audio.',
      );
    }
  }

  static void _validateDistinctPaths({
    required String sourcePath,
    required String destinationPath,
  }) {
    _validatePath(sourcePath);
    _validatePath(destinationPath);

    if (sourcePath == destinationPath) {
      throw ArgumentError.value(
        destinationPath,
        'destinationPath',
        'Source and destination paths must differ.',
      );
    }
  }

  static void _validateKeyId(String keyId) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(keyId)) {
      throw ArgumentError.value(keyId, 'keyId');
    }
  }

  static void _validatePath(String path) {
    if (path.trim().isEmpty || !path.startsWith(Platform.pathSeparator)) {
      throw ArgumentError.value(path, 'path');
    }
  }
}
