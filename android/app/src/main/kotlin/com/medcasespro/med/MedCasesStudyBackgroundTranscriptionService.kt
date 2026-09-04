package com.medcasespro.med

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import org.json.JSONArray
import java.io.File
import java.io.FileInputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.min

class MedCasesStudyBackgroundTranscriptionService : Service() {
    companion object {
        const val CHANNEL_ID = "medcases_study_background_transcription"
        const val NOTIFICATION_ID = 43402

        const val EXTRA_JOB_ID = "jobId"
        const val EXTRA_GRANT = "grant"
        const val EXTRA_UPLOAD_BASE_URL = "uploadBaseUrl"
        const val EXTRA_SEGMENTS_JSON = "segmentsJson"
    }

    @Volatile
    private var running = false

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        if (intent == null) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        val jobId = intent.getStringExtra(EXTRA_JOB_ID).orEmpty()
        val grant = intent.getStringExtra(EXTRA_GRANT).orEmpty()
        val uploadBaseUrl =
            intent.getStringExtra(EXTRA_UPLOAD_BASE_URL).orEmpty()
        val segmentsJson =
            intent.getStringExtra(EXTRA_SEGMENTS_JSON).orEmpty()

        if (
            jobId.isBlank() ||
            grant.isBlank() ||
            uploadBaseUrl.isBlank() ||
            segmentsJson.isBlank()
        ) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        startAsForeground()

        if (running) {
            return START_REDELIVER_INTENT
        }
        running = true

        Thread {
            try {
                val segments = JSONArray(segmentsJson)
                for (position in 0 until segments.length()) {
                    val segment = segments.getJSONObject(position)
                    val index = segment.getInt("index")
                    val path = segment.getString("path")
                    val mimeType =
                        segment.optString("mimeType", "audio/mp4")

                    uploadWithRetry(
                        uploadBaseUrl = uploadBaseUrl,
                        grant = grant,
                        index = index,
                        path = path,
                        mimeType = mimeType,
                    )

                    updateNotification(
                        completed = position + 1,
                        total = segments.length(),
                    )
                }
            } catch (_: Throwable) {
                // Server/local checkpoints remain authoritative.
            } finally {
                running = false
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf(startId)
            }
        }.start()

        return START_REDELIVER_INTENT
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun uploadWithRetry(
        uploadBaseUrl: String,
        grant: String,
        index: Int,
        path: String,
        mimeType: String,
    ) {
        var attempt = 0
        var delayMs = 1000L

        while (attempt < 20) {
            attempt += 1
            val code = try {
                uploadOnce(
                    uploadBaseUrl,
                    grant,
                    index,
                    path,
                    mimeType,
                )
            } catch (_: Throwable) {
                -1
            }

            if (code in 200..299) {
                return
            }

            if (code == 409) {
                Thread.sleep(1500L)
                continue
            }

            Thread.sleep(delayMs)
            delayMs = min(delayMs * 2L, 30000L)
        }

        throw IllegalStateException(
            "study_background_segment_upload_failed_$index",
        )
    }

    private fun uploadOnce(
        uploadBaseUrl: String,
        grant: String,
        index: Int,
        path: String,
        mimeType: String,
    ): Int {
        val file = File(path)
        require(file.exists() && file.isFile && file.length() > 0L)

        val url = URL(
            uploadBaseUrl.trimEnd('/') + "/" + index,
        )
        val connection = url.openConnection() as HttpURLConnection
        connection.requestMethod = "PUT"
        connection.connectTimeout = 20000
        connection.readTimeout = 180000
        connection.doOutput = true
        connection.setRequestProperty(
            "Authorization",
            "Study $grant",
        )
        connection.setRequestProperty(
            "Content-Type",
            "application/octet-stream",
        )
        connection.setRequestProperty(
            "x-medcases-audio-mime",
            mimeType,
        )
        connection.setFixedLengthStreamingMode(file.length())

        FileInputStream(file).use { input ->
            connection.outputStream.use { output ->
                input.copyTo(output, bufferSize = 64 * 1024)
            }
        }

        val code = connection.responseCode
        try {
            if (code >= 400) {
                connection.errorStream?.use { it.readBytes() }
            } else {
                connection.inputStream?.use { it.readBytes() }
            }
        } finally {
            connection.disconnect()
        }
        return code
    }

    private fun startAsForeground() {
        val notification = buildNotification(
            "Preparando transcrição em segundo plano",
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(
        completed: Int,
        total: Int,
    ) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(
            NOTIFICATION_ID,
            buildNotification(
                "Transcrição $completed/$total segmentos",
            ),
        )
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Transcrição de aulas",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description =
                "Mantém a transcrição iniciada pelo usuário ativa em segundo plano."
            setSound(null, null)
            enableVibration(false)
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    @Suppress("DEPRECATION")
    private fun buildNotification(text: String): Notification {
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
            } else {
                Notification.Builder(this)
            }

        return builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("MedCases Pro")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }
}
