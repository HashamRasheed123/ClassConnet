package com.softwareclass.softwareclass

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.MediaScannerConnection
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.MediaStore
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val powerChannel = "classconnect/alarm_power"
    private val storagePermRequestCode = 9401
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingSaveTask: ((Boolean) -> Unit)? = null
    private var pendingInstallApkPath: String? = null
    private var mediaPlayer: MediaPlayer? = null
    private var fallbackRingtone: Ringtone? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val autoStopRunnable = Runnable { stopNativeAlarm() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableLockScreenWake()
    }

    override fun onResume() {
        super.onResume()
        val apkPath = pendingInstallApkPath
        if (apkPath != null) {
            val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                packageManager.canRequestPackageInstalls()
            } else {
                true
            }
            if (canInstall) {
                pendingInstallApkPath = null
                launchApkInstallerIntent(File(apkPath))
            }
        }
    }

    private fun enableLockScreenWake() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                )
            }
        } catch (_: Exception) {
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, powerChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                            result.success(true)
                        } else {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        }
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                                result.success(true)
                            } catch (e2: Exception) {
                                result.success(false)
                            }
                        }
                    }
                    "startAlarmRinging" -> {
                        val vibrate = call.argument<Boolean>("vibrate") ?: true
                        val playSound = call.argument<Boolean>("playSound") ?: true
                        startNativeAlarm(playSound = playSound, vibrate = vibrate)
                        result.success(true)
                    }
                    "stopAlarmRinging" -> {
                        stopNativeAlarm()
                        result.success(true)
                    }
                    "ensureStoragePermission" -> {
                        ensureStoragePermission(result)
                    }
                    "saveFileToDownloads" -> {
                        val fileName = call.argument<String>("fileName") ?: "ClassConnect_Document.pdf"
                        val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty()) {
                            result.success(null)
                        } else {
                            saveFileWithPermissionCheck(fileName, mimeType, bytes, result)
                        }
                    }
                    "canRequestPackageInstalls" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            result.success(packageManager.canRequestPackageInstalls())
                        } else {
                            result.success(true)
                        }
                    }
                    "installApk" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath.isNullOrBlank()) {
                            result.success("INVALID_PATH")
                            return@setMethodCallHandler
                        }
                        val apkFile = File(filePath)
                        if (!apkFile.exists() || apkFile.length() <= 0L) {
                            result.success("FILE_NOT_FOUND")
                            return@setMethodCallHandler
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            !packageManager.canRequestPackageInstalls()
                        ) {
                            pendingInstallApkPath = apkFile.absolutePath
                            try {
                                val permIntent = Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                )
                                permIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(permIntent)
                                result.success("PERMISSION_REQUESTED")
                            } catch (e: Exception) {
                                val launched = launchApkInstallerIntent(apkFile)
                                result.success(if (launched) "INSTALLER_LAUNCHED" else "ERROR")
                            }
                        } else {
                            val launched = launchApkInstallerIntent(apkFile)
                            result.success(if (launched) "INSTALLER_LAUNCHED" else "ERROR")
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun launchApkInstallerIntent(apkFile: File): Boolean {
        return try {
            // Ensure the APK is inside getFilesDir()/ota_updates so FileProvider's <files-path>
            // (and <root-path>) resolves it cleanly on every Android OEM.
            val safeDir = File(filesDir, "ota_updates")
            if (!safeDir.exists()) {
                safeDir.mkdirs()
            }
            val targetApk = if (apkFile.absolutePath.startsWith(filesDir.absolutePath)) {
                apkFile
            } else {
                val dest = File(safeDir, apkFile.name)
                if (dest.absolutePath != apkFile.absolutePath) {
                    apkFile.copyTo(dest, overwrite = true)
                }
                dest
            }

            val apkUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    targetApk
                )
            } else {
                Uri.fromFile(targetApk)
            }
            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(installIntent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun hasLegacyStorageWritePermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return true
        }
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.WRITE_EXTERNAL_STORAGE
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun ensureStoragePermission(result: MethodChannel.Result) {
        if (hasLegacyStorageWritePermission()) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        pendingSaveTask = null
        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
                Manifest.permission.READ_EXTERNAL_STORAGE
            ),
            storagePermRequestCode
        )
    }

    private fun saveFileWithPermissionCheck(
        fileName: String,
        mimeType: String,
        bytes: ByteArray,
        result: MethodChannel.Result
    ) {
        if (hasLegacyStorageWritePermission()) {
            val savedPath = writeToPublicDownloads(fileName, mimeType, bytes)
            result.success(savedPath)
            return
        }
        pendingPermissionResult = null
        pendingSaveTask = { granted ->
            if (granted) {
                val savedPath = writeToPublicDownloads(fileName, mimeType, bytes)
                result.success(savedPath)
            } else {
                result.success(null)
            }
        }
        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission.WRITE_EXTERNAL_STORAGE,
                Manifest.permission.READ_EXTERNAL_STORAGE
            ),
            storagePermRequestCode
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == storagePermRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.let {
                it.success(granted)
                pendingPermissionResult = null
            }
            pendingSaveTask?.let { task ->
                pendingSaveTask = null
                task.invoke(granted)
            }
        }
    }

    private fun writeToPublicDownloads(
        fileName: String,
        mimeType: String,
        bytes: ByteArray
    ): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = applicationContext.contentResolver
                val contentValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    put(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        Environment.DIRECTORY_DOWNLOADS + "/ClassConnect"
                    )
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                if (uri != null) {
                    resolver.openOutputStream(uri)?.use { out ->
                        out.write(bytes)
                        out.flush()
                    }
                    contentValues.clear()
                    contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    resolver.update(uri, contentValues, null, null)
                    return "/storage/emulated/0/Download/ClassConnect/$fileName"
                }
            }

            @Suppress("DEPRECATION")
            val baseDownloads =
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val targetDir = File(baseDownloads, "ClassConnect")
            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }
            val outFile = File(targetDir, fileName)
            FileOutputStream(outFile).use { fos ->
                fos.write(bytes)
                fos.flush()
            }
            MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(outFile.absolutePath),
                arrayOf(mimeType),
                null
            )
            outFile.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveAlarmUri(): Uri? {
        return RingtoneManager.getActualDefaultRingtoneUri(applicationContext, RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getActualDefaultRingtoneUri(applicationContext, RingtoneManager.TYPE_NOTIFICATION)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
    }

    private fun getVibrator(): Vibrator? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun startNativeAlarm(playSound: Boolean, vibrate: Boolean) {
        stopNativeAlarm()

        if (playSound) {
            val alarmUri = resolveAlarmUri()
            var started = false
            if (alarmUri != null) {
                try {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                    if (audioManager != null) {
                        val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                        val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                        if (currentVol == 0 && maxVol > 0) {
                            // Ensure alarm stream is audible when user explicitly selected Ring mode
                            audioManager.setStreamVolume(
                                AudioManager.STREAM_ALARM,
                                (maxVol * 0.7).toInt().coerceAtLeast(1),
                                0
                            )
                        }
                    }

                    val mp = MediaPlayer()
                    mp.setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    mp.setDataSource(applicationContext, alarmUri)
                    mp.isLooping = true
                    mp.prepare()
                    mp.start()
                    mediaPlayer = mp
                    started = true
                } catch (_: Exception) {
                    try {
                        mediaPlayer?.release()
                    } catch (_: Exception) {
                    }
                    mediaPlayer = null
                }

                if (!started) {
                    try {
                        val rt = RingtoneManager.getRingtone(applicationContext, alarmUri)
                        if (rt != null) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                rt.audioAttributes = AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_ALARM)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                    .build()
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                rt.isLooping = true
                            }
                            rt.play()
                            fallbackRingtone = rt
                        }
                    } catch (_: Exception) {
                    }
                }
            }
        }

        if (vibrate) {
            try {
                val vibrator = getVibrator()
                val pattern = longArrayOf(0, 900, 400, 900, 400, 1200, 500)
                if (vibrator != null && vibrator.hasVibrator()) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(pattern, 0)
                    }
                }
            } catch (_: Exception) {
            }
        }

        // Auto-stop after 60 seconds so an unattended alarm doesn't drain battery indefinitely
        mainHandler.postDelayed(autoStopRunnable, 60_000L)
    }

    private fun stopNativeAlarm() {
        mainHandler.removeCallbacks(autoStopRunnable)
        try {
            mediaPlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (_: Exception) {
        }
        mediaPlayer = null

        try {
            fallbackRingtone?.stop()
        } catch (_: Exception) {
        }
        fallbackRingtone = null

        try {
            getVibrator()?.cancel()
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        stopNativeAlarm()
        super.onDestroy()
    }
}
