package io.github.muhammadtaimoorajmal.trustcue

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.nio.charset.StandardCharsets
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "trustcue/incoming_share"
    private var methodChannel: MethodChannel? = null
    private var pendingShare: Map<String, Any?>? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        processIntent(intent) { payload ->
            if (payload != null) {
                pendingShare = payload
                methodChannel?.invokeMethod("onShareReceived", payload)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        processIntent(intent) { payload ->
            if (payload != null) {
                pendingShare = payload
                methodChannel?.invokeMethod("onShareReceived", payload)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShare" -> {
                    result.success(pendingShare)
                }
                "consumeShare" -> {
                    val eventId = call.argument<String>("eventId")
                    if (eventId != null && pendingShare?.get("eventId") == eventId) {
                        pendingShare = null
                    }
                    result.success(true)
                }
                "cleanStagedFile" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        cleanStagedFile(filePath)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Deliver pending share if processed before engine was configured
        pendingShare?.let {
            channel.invokeMethod("onShareReceived", it)
        }
    }

    private fun cleanStagedFile(filePath: String): Boolean {
        return try {
            val stagingDir = File(cacheDir, "trustcue_incoming_shares").canonicalFile
            val targetFile = File(filePath).canonicalFile
            if (targetFile.parentFile?.canonicalPath == stagingDir.canonicalPath && targetFile.exists()) {
                targetFile.delete()
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun processIntent(intent: Intent?, callback: (Map<String, Any?>?) -> Unit) {
        if (intent == null || intent.action == null) {
            callback(null)
            return
        }

        // Standard launcher start is not an incoming share
        if (intent.action == Intent.ACTION_MAIN) {
            callback(null)
            return
        }

        val eventId = UUID.randomUUID().toString()

        if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            callback(
                mapOf(
                    "eventId" to eventId,
                    "type" to "unsupported",
                    "errorMessage" to "Sharing multiple items at once is not supported. Please share one message or one image."
                )
            )
            return
        }

        if (intent.action != Intent.ACTION_SEND) {
            callback(
                mapOf(
                    "eventId" to eventId,
                    "type" to "unsupported",
                    "errorMessage" to "Unsupported intent action: ${intent.action}"
                )
            )
            return
        }

        val rawText = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
        val streamUri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }

        if (rawText == null && streamUri == null) {
            callback(
                mapOf(
                    "eventId" to eventId,
                    "type" to "unsupported",
                    "errorMessage" to "No supported text or image found in the shared intent."
                )
            )
            return
        }

        // Validate text if present (bounds: 10,000 code points, 40,000 UTF-8 bytes)
        var validatedText: String? = null
        var textError: String? = null
        if (rawText != null) {
            val trimmed = rawText.trim()
            if (trimmed.isEmpty()) {
                textError = "Shared text is empty."
            } else {
                val codePoints = rawText.codePointCount(0, rawText.length)
                val utf8Bytes = rawText.toByteArray(StandardCharsets.UTF_8).size
                if (codePoints > 10000 || utf8Bytes > 40000) {
                    textError = "Shared text exceeds TrustCue's 10,000 character or 40,000 byte limit."
                } else {
                    validatedText = rawText
                }
            }
        }

        // If no image stream was provided, resolve purely text
        if (streamUri == null) {
            if (textError != null) {
                callback(
                    mapOf(
                        "eventId" to eventId,
                        "type" to "unsupported",
                        "errorMessage" to textError
                    )
                )
            } else {
                callback(
                    mapOf(
                        "eventId" to eventId,
                        "type" to "text",
                        "text" to validatedText
                    )
                )
            }
            return
        }

        // Validate content URI scheme
        if (streamUri.scheme != "content") {
            callback(
                mapOf(
                    "eventId" to eventId,
                    "type" to "unsupported",
                    "errorMessage" to "Only content:// image URIs provided by Android are supported. Direct file or web URLs cannot be imported."
                )
            )
            return
        }

        // Process image stream off the UI thread
        executor.execute {
            val stagingDir = File(cacheDir, "trustcue_incoming_shares")
            if (!stagingDir.exists()) stagingDir.mkdirs()

            var inputStream: InputStream? = null
            var outputStream: FileOutputStream? = null
            var tempFile: File? = null

            try {
                inputStream = contentResolver.openInputStream(streamUri)
                if (inputStream == null) {
                    mainHandler.post {
                        callback(
                            mapOf(
                                "eventId" to eventId,
                                "type" to "unsupported",
                                "errorMessage" to "Could not access the shared image. Permission was denied or the content is missing."
                            )
                        )
                    }
                    return@execute
                }

                val maxBytes = 10 * 1024 * 1024 // 10 MiB limit
                val tempFileName = "staging_${System.currentTimeMillis()}_${UUID.randomUUID().toString().take(8)}.tmp"
                tempFile = File(stagingDir, tempFileName)
                outputStream = FileOutputStream(tempFile)

                val buffer = ByteArray(8192)
                var totalBytes = 0
                var firstChunk = true
                var isPng = false
                var isJpeg = false

                var bytesRead = inputStream.read(buffer)
                while (bytesRead != -1) {
                    totalBytes += bytesRead
                    if (totalBytes > maxBytes) {
                        try { outputStream?.close() } catch (_: Exception) {}
                        outputStream = null
                        tempFile?.delete()
                        mainHandler.post {
                            callback(
                                mapOf(
                                    "eventId" to eventId,
                                    "type" to "unsupported",
                                    "errorMessage" to "Shared image exceeds the 10 MB size limit."
                                )
                            )
                        }
                        return@execute
                    }

                    if (firstChunk) {
                        if (bytesRead >= 3 &&
                            (buffer[0].toInt() and 0xFF) == 0xFF &&
                            (buffer[1].toInt() and 0xFF) == 0xD8 &&
                            (buffer[2].toInt() and 0xFF) == 0xFF
                        ) {
                            isJpeg = true
                        } else if (bytesRead >= 8 &&
                            (buffer[0].toInt() and 0xFF) == 0x89 &&
                            (buffer[1].toInt() and 0xFF) == 0x50 &&
                            (buffer[2].toInt() and 0xFF) == 0x4E &&
                            (buffer[3].toInt() and 0xFF) == 0x47 &&
                            (buffer[4].toInt() and 0xFF) == 0x0D &&
                            (buffer[5].toInt() and 0xFF) == 0x0A &&
                            (buffer[6].toInt() and 0xFF) == 0x1A &&
                            (buffer[7].toInt() and 0xFF) == 0x0A
                        ) {
                            isPng = true
                        } else {
                            try { outputStream?.close() } catch (_: Exception) {}
                            outputStream = null
                            tempFile?.delete()
                            mainHandler.post {
                                callback(
                                    mapOf(
                                        "eventId" to eventId,
                                        "type" to "unsupported",
                                        "errorMessage" to "Shared image format is not supported. Only PNG and JPEG images can be examined."
                                    )
                                )
                            }
                            return@execute
                        }
                        firstChunk = false
                    }

                    outputStream?.write(buffer, 0, bytesRead)
                    bytesRead = inputStream.read(buffer)
                }

                outputStream?.flush()
                outputStream?.close()
                outputStream = null

                val extension = if (isPng) ".png" else ".jpg"
                val finalFileName = "share_${System.currentTimeMillis()}_${UUID.randomUUID().toString().take(8)}$extension"
                val finalFile = File(stagingDir, finalFileName)

                if (tempFile != null && tempFile.renameTo(finalFile)) {
                    val mimeType = if (isPng) "image/png" else "image/jpeg"
                    mainHandler.post {
                        if (validatedText != null) {
                            // Intent provided both a valid image and accompanying text
                            callback(
                                mapOf(
                                    "eventId" to eventId,
                                    "type" to "mixed",
                                    "text" to validatedText,
                                    "imagePath" to finalFile.absolutePath,
                                    "mimeType" to mimeType
                                )
                            )
                        } else {
                            callback(
                                mapOf(
                                    "eventId" to eventId,
                                    "type" to "image",
                                    "imagePath" to finalFile.absolutePath,
                                    "mimeType" to mimeType
                                )
                            )
                        }
                    }
                } else {
                    tempFile?.delete()
                    mainHandler.post {
                        callback(
                            mapOf(
                                "eventId" to eventId,
                                "type" to "unsupported",
                                "errorMessage" to "Failed to stage shared image file."
                            )
                        )
                    }
                }
            } catch (se: SecurityException) {
                tempFile?.delete()
                mainHandler.post {
                    callback(
                        mapOf(
                            "eventId" to eventId,
                            "type" to "unsupported",
                            "errorMessage" to "Permission to read the shared image was denied."
                        )
                    )
                }
            } catch (e: Exception) {
                tempFile?.delete()
                mainHandler.post {
                    callback(
                        mapOf(
                            "eventId" to eventId,
                            "type" to "unsupported",
                            "errorMessage" to "Failed to read the shared image: ${e.localizedMessage ?: "I/O error"}"
                        )
                    )
                }
            } finally {
                try { inputStream?.close() } catch (_: Exception) {}
                try { outputStream?.close() } catch (_: Exception) {}
            }
        }
    }
}
