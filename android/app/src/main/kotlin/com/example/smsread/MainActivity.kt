package com.example.smsread

import android.Manifest
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "sms_tracker/sms"
    private val SMS_PERMISSION_REQUEST_CODE = 123

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSmsPermission" -> {
                    result.success(hasSmsPermission())
                }
                "requestSmsPermission" -> {
                    if (!hasSmsPermission()) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_SMS),
                            SMS_PERMISSION_REQUEST_CODE,
                        )
                        result.success(false)
                    } else {
                        result.success(true)
                    }
                }
                "getAllSms" -> {
                    if (hasSmsPermission()) {
                        try {
                            val smsList = getAllSms()
                            result.success(smsList)
                        } catch (e: Exception) {
                            result.error("SMS_READ_ERROR", "Failed to read SMS: ${e.message}", null)
                        }
                    } else {
                        result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasSmsPermission(): Boolean {
        val permission =
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_SMS,
            )
        return permission == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            SMS_PERMISSION_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    println("SMS Permission granted")
                } else {
                    println("SMS Permission denied")
                }
            }
        }
    }

    private fun getAllSms(): List<Map<String, Any?>> {
        val smsList = mutableListOf<Map<String, Any?>>()

        try {
            println("Starting SMS read operation...")

            val cursor: Cursor? =
                contentResolver.query(
                    Uri.parse("content://sms/inbox"),
                    arrayOf("_id", "address", "body", "date", "type"),
                    null,
                    null,
                    "date DESC LIMIT 1000",
                )

            cursor?.use {
                println("SMS cursor obtained. Count: ${it.count}")

                val idIndex = it.getColumnIndex("_id")
                val addressIndex = it.getColumnIndex("address")
                val bodyIndex = it.getColumnIndex("body")
                val dateIndex = it.getColumnIndex("date")
                val typeIndex = it.getColumnIndex("type")

                var count = 0
                while (it.moveToNext()) {
                    val smsMap =
                        mapOf<String, Any?>(
                            "id" to it.getString(idIndex),
                            "address" to it.getString(addressIndex),
                            "body" to it.getString(bodyIndex),
                            "date" to it.getLong(dateIndex),
                            "type" to it.getInt(typeIndex),
                        )
                    smsList.add(smsMap)
                    count++
                }
                println("Successfully read $count SMS messages")
            } ?: run {
                println("Failed to obtain SMS cursor")
            }
        } catch (e: Exception) {
            println("Error reading SMS: ${e.message}")
            e.printStackTrace()
        }

        println("Returning ${smsList.size} SMS messages")
        return smsList
    }
}
