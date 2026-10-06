package com.medcasespro.med

import android.app.AlertDialog
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.time.Instant

object MedCasesOrganizationChannel {
    private const val TIMER = 700002
    fun register(activity: FlutterActivity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "medcases/organization_v1")
            .setMethodCallHandler { call, result ->
                try {
                    val manager = activity.getSystemService(NotificationManager::class.java)
                    when (call.method) {
                        "endTimer" -> { manager.cancel(TIMER); result.success(null) }
                        "timer" -> {
                            val status = call.argument<String>("status")
                            if (status != "running") { manager.cancel(TIMER); result.success(null) }
                            else {
                                val end = Instant.parse(call.argument<String>("targetEndTime")).toEpochMilli()
                                val es = call.argument<Boolean>("isEs") == true
                                if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
                                    NotificationChannel("medcases_organization_active", "MedCases Timer", NotificationManager.IMPORTANCE_LOW))
                                val intent = Intent(activity, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                val pending = PendingIntent.getActivity(activity, TIMER, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                                val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(activity, "medcases_organization_active") else Notification.Builder(activity)
                                builder.setSmallIcon(activity.applicationInfo.icon).setContentTitle("MedCases · Timer")
                                    .setContentText(if (es) "En curso" else "Em andamento")
                                    .setWhen(end).setUsesChronometer(true).setOngoing(true)
                                    .setVisibility(Notification.VISIBILITY_PUBLIC).setContentIntent(pending)
                                if (Build.VERSION.SDK_INT >= 24) builder.setChronometerCountDown(true)
                                if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter((end-System.currentTimeMillis()).coerceAtLeast(1))
                                manager.notify(TIMER, builder.build()); result.success(null)
                            }
                        }
                        "saveCalendar" -> {
                            val owner = call.argument<String>("owner") ?: throw IllegalArgumentException()
                            if (com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid != owner) throw SecurityException()
                            val id = call.argument<String>("id") ?: throw IllegalArgumentException()
                            val marker = "medcases://agenda/$owner/$id"
                            val resolver = activity.contentResolver
                            var existing = call.argument<String>("nativeId")?.toLongOrNull()
                            if (existing == null) resolver.query(CalendarContract.Events.CONTENT_URI,
                                arrayOf(CalendarContract.Events._ID), "${CalendarContract.Events.CUSTOM_APP_URI} = ?", arrayOf(marker), null)?.use { if (it.moveToFirst()) existing = it.getLong(0) }
                            val calendars = mutableListOf<Pair<Long,String>>()
                            resolver.query(CalendarContract.Calendars.CONTENT_URI, arrayOf(CalendarContract.Calendars._ID, CalendarContract.Calendars.CALENDAR_DISPLAY_NAME),
                                "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ?", arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString()), null)?.use {
                                while(it.moveToNext()) calendars.add(it.getLong(0) to it.getString(1))
                            }
                            if(calendars.isEmpty()) { result.error("CALENDAR_UNAVAILABLE",null,null); return@setMethodCallHandler }
                            fun save(calendar: Long) {
                                try {
                                    if (com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid != owner) throw SecurityException()
                                    val start = (call.argument<Number>("startMs") ?: throw IllegalArgumentException()).toLong()
                                    val end = (call.argument<Number>("endMs") ?: throw IllegalArgumentException()).toLong()
                                    val values = ContentValues().apply {
                                        put(CalendarContract.Events.CALENDAR_ID,calendar); put(CalendarContract.Events.TITLE,call.argument<String>("title"))
                                        put(CalendarContract.Events.DESCRIPTION,call.argument<String>("notes")); put(CalendarContract.Events.DTSTART,start)
                                        put(CalendarContract.Events.EVENT_TIMEZONE,java.util.TimeZone.getDefault().id)
                                        put(CalendarContract.Events.CUSTOM_APP_PACKAGE,activity.packageName); put(CalendarContract.Events.CUSTOM_APP_URI,marker)
                                        val recurrence=call.argument<String>("recurrence")
                                        val frequency=when(recurrence){"daily"->"DAILY";"weekly"->"WEEKLY";"monthly"->"MONTHLY";else->null}
                                        if(frequency==null){putNull(CalendarContract.Events.RRULE);putNull(CalendarContract.Events.DURATION);put(CalendarContract.Events.DTEND,end)}
                                        else {put(CalendarContract.Events.RRULE,"FREQ=$frequency");putNull(CalendarContract.Events.DTEND);put(CalendarContract.Events.DURATION,"PT${(end-start)/1000}S")}
                                    }
                                    val current=existing
                                    val nativeId = if(current==null) resolver.insert(CalendarContract.Events.CONTENT_URI,values)?.let{ContentUris.parseId(it)}
                                    else { val uri=ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI,current)
                                        // Owner marker must still match before changing a native event.
                                        val safe=resolver.query(uri,arrayOf(CalendarContract.Events.CUSTOM_APP_URI),null,null,null)?.use{it.moveToFirst()&&it.getString(0)==marker}==true
                                        if(!safe)throw IllegalStateException(); resolver.update(uri,values,null,null);current }
                                    if(nativeId==null)throw IllegalStateException();result.success(nativeId.toString())
                                }catch(_:Exception){result.error("CALENDAR_WRITE_FAILED",null,null)}
                            }
                            AlertDialog.Builder(activity).setTitle(if(call.argument<Boolean>("isEs")==true) "Elegí un calendario" else "Escolha um calendário")
                                .setItems(calendars.map{it.second}.toTypedArray()){_,index->save(calendars[index].first)}
                                .setOnCancelListener{result.error("CALENDAR_CANCELLED",null,null)}.show()
                        }
                        "deleteCalendar" -> {
                            if (com.google.firebase.auth.FirebaseAuth.getInstance().currentUser?.uid != call.argument<String>("owner")) throw SecurityException()
                            val id=call.argument<String>("nativeId")?.toLongOrNull() ?: throw IllegalArgumentException()
                            val marker="medcases://agenda/${call.argument<String>("owner")}/${call.argument<String>("id")}"
                            val uri=ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI,id)
                            val safe=activity.contentResolver.query(uri,arrayOf(CalendarContract.Events.CUSTOM_APP_URI),null,null,null)?.use{it.moveToFirst()&&it.getString(0)==marker}==true
                            if(safe)activity.contentResolver.delete(uri,null,null)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch(_:Exception) { result.error("ORGANIZATION_NATIVE_FAILED",null,null) }
            }
    }
}
