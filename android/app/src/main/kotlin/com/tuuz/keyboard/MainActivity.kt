package com.tuuz.keyboard

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private companion object {
        /// 与 Dart 侧 UpdateStore 对应的通道名称
        const val CHANNEL = "flutter_tuuzkb/installer"
        const val APK_MIME = "application/vnd.android.package-archive"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCacheDir" -> result.success(cacheDir.absolutePath)
                    "canInstall" -> result.success(canRequestInstall())
                    "openInstallPermissionSettings" -> {
                        openInstallPermissionSettings()
                        result.success(true)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrEmpty()) {
                            result.error("invalid_args", "apk path is empty", null)
                        } else {
                            installApk(File(path), result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Android 8.0+ 安装未知来源应用需要用户手动授权
    private fun canRequestInstall(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                packageManager.canRequestPackageInstalls()
    }

    /// 跳转到系统的"安装未知应用"授权页面
    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName"),
        )
        startActivity(intent)
    }

    /// 调起系统安装器安装已下载的 APK
    private fun installApk(file: File, result: MethodChannel.Result) {
        if (!canRequestInstall()) {
            openInstallPermissionSettings()
            result.error("no_permission", "缺少安装未知应用权限", null)
            return
        }
        try {
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, APK_MIME)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("install_failed", e.message, null)
        }
    }
}
