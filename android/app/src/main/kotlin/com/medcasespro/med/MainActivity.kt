package com.medcasespro.med

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.system.Os
import android.system.OsConstants
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MedCasesLongFormAtRestChannel.register(
            activity = this,
            flutterEngine = flutterEngine,
        )
        MedCasesRecordingBackgroundChannel.register(
            activity = this,
            flutterEngine = flutterEngine,
        )
        MedCasesStudyBackgroundTranscriptionChannel.register(
            activity = this,
            flutterEngine = flutterEngine,
        )
    }
}

private object MedCasesLongFormAtRestChannel {
    private const val CHANNEL = "medcases/audio_at_rest_v2"
    private const val ROOT_NAME = "medcases_long_form_secure"
    private const val KEY_ALIAS_PREFIX = "medcases.longform.aesgcm."
    private const val KEY_STORE = "AndroidKeyStore"
    private const val CIPHER = "AES/GCM/NoPadding"
    private const val ENVELOPE_SCHEMA =
        "medcases.long_form_sensitive_envelope.v1"
    private const val ALGORITHM_NAME = "AES-256-GCM"
    private const val GCM_TAG_BITS = 128
    private const val NONCE_BYTES = 12

    private val allowedAssetKinds = setOf(
        "activeAudioSegment",
        "closedAudioSegment",
        "recordingManifest",
        "batchQueue",
        "segmentTranscriptCheckpoint",
        "reviewedTranscript",
        "retentionMetadata",
        "transportPlaintextStaging",
    )

    fun register(
        activity: MainActivity,
        flutterEngine: FlutterEngine,
    ) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "capabilities" -> {
                        result.success(
                            mapOf(
                                "platform" to "android",
                                "channel" to CHANNEL,
                                "secureRootKind" to "noBackupFilesDir",
                                "activeFileProtection" to "appPrivateNoBackup",
                                "durableFileProtection" to "appPrivateNoBackup",
                                "keyStore" to KEY_STORE,
                                "cipher" to ALGORITHM_NAME,
                                "keyExportToFlutter" to false,
                                "productionIntegrationEnabled" to false,
                            ),
                        )
                    }

                    "secureRoot" -> {
                        result.success(secureRoot(activity).absolutePath)
                    }

                    "protectActiveAudioFile",
                    "protectDurableFile",
                    -> {
                        val path = requiredString(
                            call.argument<Any?>("path"),
                            "path",
                        )
                        validateProtectedFile(
                            activity = activity,
                            path = path,
                        )
                        result.success(null)
                    }

                    "seal" -> {
                        requireApi23()
                        val identity = cryptoIdentity(call.arguments)
                        val clear = requiredBytes(
                            call.argument<Any?>("clearText"),
                            "clearText",
                        )
                        val key = loadOrCreateKey(identity.keyId)
                        val cipher = Cipher.getInstance(CIPHER)
                        cipher.init(Cipher.ENCRYPT_MODE, key)

                        val iv = cipher.iv
                        if (iv.size != NONCE_BYTES) {
                            throw BridgeFailure(
                                "android_nonce_length_unexpected",
                            )
                        }

                        cipher.updateAAD(identity.aad)
                        val encrypted = cipher.doFinal(clear)
                        result.success(iv + encrypted)
                    }

                    "open" -> {
                        requireApi23()
                        val identity = cryptoIdentity(call.arguments)
                        val sealed = requiredBytes(
                            call.argument<Any?>("sealedData"),
                            "sealedData",
                        )

                        if (sealed.size <= NONCE_BYTES + 16) {
                            throw BridgeFailure(
                                "android_sealed_payload_invalid",
                            )
                        }

                        val iv = sealed.copyOfRange(0, NONCE_BYTES)
                        val cipherText = sealed.copyOfRange(
                            NONCE_BYTES,
                            sealed.size,
                        )

                        val key = loadExistingKey(identity.keyId)
                        val cipher = Cipher.getInstance(CIPHER)
                        cipher.init(
                            Cipher.DECRYPT_MODE,
                            key,
                            GCMParameterSpec(GCM_TAG_BITS, iv),
                        )
                        cipher.updateAAD(identity.aad)
                        result.success(cipher.doFinal(cipherText))
                    }

                    "sealFile" -> {
                        requireApi23()
                        val identity = cryptoIdentity(call.arguments)
                        requireClosedAudioIdentity(identity)
                        val source = existingRegularFile(
                            activity = activity,
                            path = requiredString(
                                call.argument<Any?>("sourcePath"),
                                "sourcePath",
                            ),
                        )
                        val destination = destinationFile(
                            activity = activity,
                            path = requiredString(
                                call.argument<Any?>("destinationPath"),
                                "destinationPath",
                            ),
                        )

                        val clear = source.readBytes()
                        val key = loadOrCreateKey(identity.keyId)
                        val cipher = Cipher.getInstance(CIPHER)
                        cipher.init(Cipher.ENCRYPT_MODE, key)

                        val iv = cipher.iv
                        if (iv.size != NONCE_BYTES) {
                            throw BridgeFailure(
                                "android_nonce_length_unexpected",
                            )
                        }

                        cipher.updateAAD(identity.aad)
                        val sealed = iv + cipher.doFinal(clear)
                        writeNativeFileCryptoOutput(
                            destination = destination,
                            data = sealed,
                        )

                        result.success(
                            mapOf(
                                "path" to destination.absolutePath,
                                "byteCount" to sealed.size,
                            ),
                        )
                    }

                    "openFile" -> {
                        requireApi23()
                        val identity = cryptoIdentity(call.arguments)
                        requireClosedAudioIdentity(identity)
                        val source = existingRegularFile(
                            activity = activity,
                            path = requiredString(
                                call.argument<Any?>("sourcePath"),
                                "sourcePath",
                            ),
                        )
                        val destination = destinationFile(
                            activity = activity,
                            path = requiredString(
                                call.argument<Any?>("destinationPath"),
                                "destinationPath",
                            ),
                        )

                        val sealed = source.readBytes()
                        if (sealed.size <= NONCE_BYTES + 16) {
                            throw BridgeFailure(
                                "android_sealed_payload_invalid",
                            )
                        }

                        val iv = sealed.copyOfRange(0, NONCE_BYTES)
                        val cipherText = sealed.copyOfRange(
                            NONCE_BYTES,
                            sealed.size,
                        )
                        val key = loadExistingKey(identity.keyId)
                        val cipher = Cipher.getInstance(CIPHER)
                        cipher.init(
                            Cipher.DECRYPT_MODE,
                            key,
                            GCMParameterSpec(GCM_TAG_BITS, iv),
                        )
                        cipher.updateAAD(identity.aad)
                        val clear = cipher.doFinal(cipherText)

                        writeNativeFileCryptoOutput(
                            destination = destination,
                            data = clear,
                        )

                        result.success(
                            mapOf(
                                "path" to destination.absolutePath,
                                "byteCount" to clear.size,
                            ),
                        )
                    }

                    else -> result.notImplemented()
                }
            } catch (failure: BridgeFailure) {
                result.error(failure.code, null, null)
            } catch (_: Throwable) {
                result.error(
                    "android_at_rest_native_failure",
                    null,
                    null,
                )
            }
        }
    }

    private data class CryptoIdentity(
        val keyId: String,
        val assetKind: String,
        val aad: ByteArray,
    )

    private class BridgeFailure(
        val code: String,
    ) : RuntimeException()

    private fun requireApi23() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            throw BridgeFailure("android_api_23_required")
        }
    }

    private fun secureRoot(activity: MainActivity): File {
        val root = File(
            activity.noBackupFilesDir,
            ROOT_NAME,
        )

        if (!root.exists() && !root.mkdirs()) {
            throw BridgeFailure(
                "android_secure_root_create_failed",
            )
        }

        if (!root.isDirectory) {
            throw BridgeFailure(
                "android_secure_root_invalid",
            )
        }

        return root.canonicalFile
    }

    private fun validateProtectedFile(
        activity: MainActivity,
        path: String,
    ) {
        val root = secureRoot(activity)
        val file = File(path).canonicalFile

        val prefix = root.path + File.separator
        if (!file.path.startsWith(prefix)) {
            throw BridgeFailure(
                "android_path_outside_secure_root",
            )
        }

        if (!file.exists() || !file.isFile) {
            throw BridgeFailure(
                "android_protected_file_missing",
            )
        }
    }

    private fun isSymbolicLink(file: File): Boolean {
        return try {
            OsConstants.S_ISLNK(
                Os.lstat(file.absolutePath).st_mode,
            )
        } catch (_: Throwable) {
            false
        }
    }

    private fun requireClosedAudioIdentity(
        identity: CryptoIdentity,
    ) {
        if (identity.assetKind != "closedAudioSegment") {
            throw BridgeFailure(
                "android_file_crypto_requires_closed_audio",
            )
        }
    }

    private fun existingRegularFile(
        activity: MainActivity,
        path: String,
    ): File {
        val root = secureRoot(activity)
        val file = File(path)

        if (isSymbolicLink(file)) {
            throw BridgeFailure(
                "android_file_crypto_symlink_forbidden",
            )
        }

        val canonical = file.canonicalFile
        val prefix = root.path + File.separator
        if (!canonical.path.startsWith(prefix)) {
            throw BridgeFailure(
                "android_path_outside_secure_root",
            )
        }

        if (!canonical.exists() || !canonical.isFile) {
            throw BridgeFailure(
                "android_file_crypto_source_not_regular",
            )
        }

        return canonical
    }

    private fun destinationFile(
        activity: MainActivity,
        path: String,
    ): File {
        val root = secureRoot(activity)
        val destination = File(path)

        if (destination.exists()) {
            throw BridgeFailure(
                "android_file_crypto_destination_exists",
            )
        }

        val parent = destination.parentFile
            ?: throw BridgeFailure(
                "android_file_crypto_parent_invalid",
            )

        if (isSymbolicLink(parent)) {
            throw BridgeFailure(
                "android_file_crypto_parent_symlink_forbidden",
            )
        }

        val canonicalParent = parent.canonicalFile
        val prefix = root.path + File.separator
        if (!canonicalParent.path.startsWith(prefix)) {
            throw BridgeFailure(
                "android_path_outside_secure_root",
            )
        }

        if (!canonicalParent.exists() || !canonicalParent.isDirectory) {
            throw BridgeFailure(
                "android_file_crypto_parent_invalid",
            )
        }

        return File(
            canonicalParent,
            destination.name,
        )
    }

    private fun writeNativeFileCryptoOutput(
        destination: File,
        data: ByteArray,
    ) {
        val parent = destination.parentFile
            ?: throw BridgeFailure(
                "android_file_crypto_parent_invalid",
            )
        val temporary = File(
            parent,
            ".${destination.name}.${System.nanoTime()}.tmp",
        )

        try {
            java.io.FileOutputStream(temporary).use { output ->
                output.write(data)
                output.fd.sync()
            }

            if (!temporary.renameTo(destination)) {
                throw BridgeFailure(
                    "android_file_crypto_promote_failed",
                )
            }
        } finally {
            if (temporary.exists()) {
                temporary.delete()
            }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun cryptoIdentity(
        arguments: Any?,
    ): CryptoIdentity {
        val args = arguments as? Map<String, Any?>
            ?: throw BridgeFailure(
                "android_arguments_invalid",
            )

        val keyId = requiredString(
            args["keyId"],
            "keyId",
        )
        val sessionId = requiredString(
            args["sessionId"],
            "sessionId",
        )
        val assetKind = requiredString(
            args["assetKind"],
            "assetKind",
        )
        val logicalName = requiredString(
            args["logicalName"],
            "logicalName",
        )

        if (!Regex("^[A-Za-z0-9._-]{1,64}$").matches(keyId)) {
            throw BridgeFailure("android_key_id_invalid")
        }

        if (!Regex("^[A-Za-z0-9._-]{1,96}$").matches(sessionId)) {
            throw BridgeFailure("android_session_id_invalid")
        }

        if (!Regex("^[A-Za-z0-9._-]{1,128}$").matches(logicalName)) {
            throw BridgeFailure("android_logical_name_invalid")
        }

        if (!allowedAssetKinds.contains(assetKind)) {
            throw BridgeFailure("android_asset_kind_invalid")
        }

        val aad = listOf(
            ENVELOPE_SCHEMA,
            ALGORITHM_NAME,
            keyId,
            sessionId,
            assetKind,
            logicalName,
        ).joinToString("\n").toByteArray(Charsets.UTF_8)

        return CryptoIdentity(
            keyId = keyId,
            assetKind = assetKind,
            aad = aad,
        )
    }

    private fun requiredString(
        value: Any?,
        name: String,
    ): String {
        val text = value as? String
            ?: throw BridgeFailure(
                "android_argument_${name}_invalid",
            )

        if (text.isBlank()) {
            throw BridgeFailure(
                "android_argument_${name}_invalid",
            )
        }

        return text
    }

    private fun requiredBytes(
        value: Any?,
        name: String,
    ): ByteArray {
        return value as? ByteArray
            ?: throw BridgeFailure(
                "android_argument_${name}_invalid",
            )
    }

    @Synchronized
    private fun loadOrCreateKey(
        keyId: String,
    ): SecretKey {
        val existing = loadExistingKeyOrNull(keyId)
        if (existing != null) {
            return existing
        }

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            KEY_STORE,
        )

        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS_PREFIX + keyId,
            KeyProperties.PURPOSE_ENCRYPT or
                KeyProperties.PURPOSE_DECRYPT,
        )
            .setKeySize(256)
            .setBlockModes(
                KeyProperties.BLOCK_MODE_GCM,
            )
            .setEncryptionPaddings(
                KeyProperties.ENCRYPTION_PADDING_NONE,
            )
            .build()

        generator.init(spec)
        return generator.generateKey()
    }

    private fun loadExistingKey(
        keyId: String,
    ): SecretKey {
        return loadExistingKeyOrNull(keyId)
            ?: throw BridgeFailure(
                "android_key_not_found",
            )
    }

    private fun loadExistingKeyOrNull(
        keyId: String,
    ): SecretKey? {
        val keyStore = KeyStore.getInstance(
            KEY_STORE,
        ).apply {
            load(null)
        }

        val alias = KEY_ALIAS_PREFIX + keyId

        if (!keyStore.containsAlias(alias)) {
            return null
        }

        return keyStore.getKey(alias, null) as? SecretKey
            ?: throw BridgeFailure(
                "android_key_material_invalid",
            )
    }
}

private object MedCasesRecordingBackgroundChannel {
    private const val CHANNEL =
        "medcases/recording_background_guard_v1"

    fun register(
        activity: MainActivity,
        flutterEngine: FlutterEngine,
    ) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "begin" -> {
                        val intent = android.content.Intent(
                            activity,
                            MedCasesRecordingForegroundService::class.java,
                        )
                        if (Build.VERSION.SDK_INT >=
                            Build.VERSION_CODES.O
                        ) {
                            activity.startForegroundService(intent)
                        } else {
                            activity.startService(intent)
                        }
                        result.success(true)
                    }

                    "end" -> {
                        val intent = android.content.Intent(
                            activity,
                            MedCasesRecordingForegroundService::class.java,
                        )
                        activity.stopService(intent)
                        result.success(true)
                    }

                    "capabilities" -> {
                        result.success(
                            mapOf(
                                "platform" to "android",
                                "minimumApi" to 24,
                                "microphoneForegroundService" to true,
                            ),
                        )
                    }

                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error(
                    "android_recording_background_guard_failure",
                    error.message,
                    null,
                )
            }
        }
    }
}

private object MedCasesStudyBackgroundTranscriptionChannel {
    private const val CHANNEL =
        "medcases/study_background_transcription_v1"

    fun register(
        activity: MainActivity,
        flutterEngine: FlutterEngine,
    ) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "enqueue") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val jobId = call.argument<String>("jobId").orEmpty()
                val grant = call.argument<String>("grant").orEmpty()
                val uploadBaseUrl =
                    call.argument<String>("uploadBaseUrl").orEmpty()
                val segments =
                    call.argument<List<Map<String, Any?>>>("segments")
                        ?: emptyList()

                if (
                    jobId.isBlank() ||
                    grant.isBlank() ||
                    uploadBaseUrl.isBlank() ||
                    segments.isEmpty()
                ) {
                    result.error(
                        "android_background_transcription_arguments_invalid",
                        null,
                        null,
                    )
                    return@setMethodCallHandler
                }

                val json = org.json.JSONArray()
                for (segment in segments) {
                    val item = org.json.JSONObject()
                    item.put("index", segment["index"])
                    item.put("path", segment["path"])
                    item.put(
                        "mimeType",
                        segment["mimeType"] ?: "audio/mp4",
                    )
                    json.put(item)
                }

                val intent = android.content.Intent(
                    activity,
                    MedCasesStudyBackgroundTranscriptionService::class.java,
                ).apply {
                    putExtra(
                        MedCasesStudyBackgroundTranscriptionService.EXTRA_JOB_ID,
                        jobId,
                    )
                    putExtra(
                        MedCasesStudyBackgroundTranscriptionService.EXTRA_GRANT,
                        grant,
                    )
                    putExtra(
                        MedCasesStudyBackgroundTranscriptionService.EXTRA_UPLOAD_BASE_URL,
                        uploadBaseUrl,
                    )
                    putExtra(
                        MedCasesStudyBackgroundTranscriptionService.EXTRA_SEGMENTS_JSON,
                        json.toString(),
                    )
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity.startForegroundService(intent)
                } else {
                    activity.startService(intent)
                }

                result.success(true)
            } catch (error: Throwable) {
                result.error(
                    "android_background_transcription_enqueue_failed",
                    error.message,
                    null,
                )
            }
        }
    }
}
