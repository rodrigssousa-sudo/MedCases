package com.medcasespro.med

import android.app.PendingIntent
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class MedCasesRecordingForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "medcases_recording_background"
        const val NOTIFICATION_ID = 43401
    }

    private var isEs = false
    private var paused = false

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        isEs = intent?.getStringExtra("language")?.startsWith("es") ?: isEs
        paused = intent?.getBooleanExtra("paused", false) ?: paused
        val notification = buildNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Gravação de áudio",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description =
                "Mantém a gravação iniciada pelo usuário ativa em segundo plano."
            setSound(null, null)
            enableVibration(false)
        }

        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    @Suppress("DEPRECATION")
    private fun buildNotification(): Notification {
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, CHANNEL_ID)
            } else {
                Notification.Builder(this)
            }

        return builder
            .setContentIntent(PendingIntent.getActivity(this, NOTIFICATION_ID,
                Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("MedCases Pro")
            .setContentText(if (paused) { if (isEs) "Grabación pausada" else "Gravação pausada" } else { if (isEs) "Grabación de audio en curso" else "Gravação de áudio em andamento" })
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }
}
