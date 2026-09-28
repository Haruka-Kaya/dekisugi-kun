package jp.dekisugi.dekisugi

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.os.Bundle
import android.os.Build
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import java.util.UUID

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val narrationChannelName = "jp.dekisugi.dekisugi/local_narration"
    private val speechChannelName = "jp.dekisugi.dekisugi/on_device_speech_recognition"
    private val microphonePermissionRequest = 7301
    private var textToSpeech: TextToSpeech? = null
    private var ttsReady = false
    private var pendingSpeak: PendingSpeak? = null
    private var pendingBundledNarration: PendingBundledNarration? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingRecognition: MethodChannel.Result? = null
    private var pendingRecognitionLanguage = "ja-JP"
    private var speechBegan = false
    private var inForeground = false

    private data class PendingSpeak(
        val utteranceId: String,
        val result: MethodChannel.Result,
    )

    private data class PendingBundledNarration(
        val player: MediaPlayer,
        val temporaryFile: File,
        val result: MethodChannel.Result,
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        textToSpeech = TextToSpeech(applicationContext, this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, narrationChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playBundledHumanRecording" -> {
                        val assetPath = call.argument<String>("assetPath")?.trim().orEmpty()
                        playBundledHumanRecording(assetPath, result)
                    }
                    "speak" -> {
                        val text = call.argument<String>("text")?.trim().orEmpty()
                        val language = call.argument<String>("language") ?: "ja-JP"
                        if (
                            text.isEmpty() ||
                            text.length > 800 ||
                            !ttsReady ||
                            !inForeground
                        ) {
                            result.success(false)
                        } else {
                            speak(text, language, result)
                        }
                    }
                    "stop" -> {
                        stopPending(false)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, speechChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recognize" -> {
                        val language = call.argument<String>("language")?.trim().orEmpty()
                        if (language.isEmpty() || language.length > 35 || pendingRecognition != null) {
                            result.success(mapOf("status" to "failed"))
                        } else {
                            beginOnDeviceRecognition(language, result)
                        }
                    }
                    "stop" -> {
                        speechRecognizer?.stopListening()
                        result.success(null)
                    }
                    "cancel" -> {
                        cancelRecognition("cancelled")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun beginOnDeviceRecognition(language: String, result: MethodChannel.Result) {
        pendingRecognition = result
        pendingRecognitionLanguage = language
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), microphonePermissionRequest)
            return
        }
        startOnDeviceRecognition()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != microphonePermissionRequest || pendingRecognition == null) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            startOnDeviceRecognition()
        } else {
            finishRecognition("permissionDenied")
        }
    }

    private fun startOnDeviceRecognition() {
        if (pendingRecognition == null) return
        if (
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(applicationContext)
        ) {
            finishRecognition("unavailable")
            return
        }
        val recognizer = try {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(applicationContext)
        } catch (_: UnsupportedOperationException) {
            finishRecognition("unavailable")
            return
        } catch (_: RuntimeException) {
            finishRecognition("failed")
            return
        }
        speechRecognizer = recognizer
        speechBegan = false
        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = Unit

            override fun onBeginningOfSpeech() {
                speechBegan = true
            }

            override fun onRmsChanged(rmsdB: Float) = Unit

            override fun onBufferReceived(buffer: ByteArray?) = Unit

            override fun onEndOfSpeech() = Unit

            override fun onError(error: Int) {
                val status = when (error) {
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "permissionDenied"
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "noSpeech"
                    SpeechRecognizer.ERROR_NO_MATCH -> if (speechBegan) {
                        "unrelatedSpeech"
                    } else {
                        "noSpeech"
                    }
                    SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
                    SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "unavailable"
                    else -> "failed"
                }
                finishRecognition(status)
            }

            override fun onResults(results: Bundle?) {
                val candidates = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.map(String::trim)
                    ?.filter(String::isNotEmpty)
                    ?.take(10)
                    .orEmpty()
                if (candidates.isEmpty()) {
                    finishRecognition(if (speechBegan) "unrelatedSpeech" else "noSpeech")
                } else {
                    finishRecognition("recognized", candidates)
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                if (!partialResults
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        .isNullOrEmpty()
                ) {
                    speechBegan = true
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, pendingRecognitionLanguage)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 10)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            // createOnDeviceSpeechRecognizerが本体。これは実装差への追加防御であり、
            // 通常recognizerへfallbackするためには使わない。
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }
        try {
            recognizer.startListening(intent)
        } catch (_: RuntimeException) {
            finishRecognition("failed")
        }
    }

    private fun finishRecognition(status: String, candidates: List<String> = emptyList()) {
        val result = pendingRecognition ?: return
        pendingRecognition = null
        speechRecognizer?.destroy()
        speechRecognizer = null
        speechBegan = false
        val payload = mutableMapOf<String, Any>("status" to status)
        if (status == "recognized") payload["candidates"] = candidates
        result.success(payload)
    }

    private fun cancelRecognition(status: String) {
        speechRecognizer?.cancel()
        finishRecognition(status)
    }

    override fun onInit(status: Int) {
        val tts = textToSpeech
        if (status != TextToSpeech.SUCCESS || tts == null) {
            ttsReady = false
            return
        }
        ttsReady = true
        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit

            override fun onDone(utteranceId: String?) {
                finishPending(utteranceId, true)
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                finishPending(utteranceId, false)
            }

            override fun onError(utteranceId: String?, errorCode: Int) {
                finishPending(utteranceId, false)
            }

            override fun onStop(utteranceId: String?, interrupted: Boolean) {
                finishPending(utteranceId, false)
            }
        })
    }

    private fun speak(text: String, languageTag: String, result: MethodChannel.Result) {
        val tts = textToSpeech ?: run {
            result.success(false)
            return
        }
        stopPending(false)
        val locale = Locale.forLanguageTag(languageTag)
        // 学校の端末内モードで本文を外へ送らないため、network-required voiceは
        // 選ばない。端末に埋込みvoiceが無ければFlutter側の文字経路へ退避する。
        val embeddedVoice = tts.voices
            .filter { voice ->
                    !voice.isNetworkConnectionRequired &&
                    voice.locale.language == locale.language &&
                    voice.features?.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED) != true
            }
            .sortedWith(
                compareByDescending<android.speech.tts.Voice> {
                    it.locale.country == locale.country
                }.thenByDescending { it.quality }.thenBy { it.name },
            )
            .firstOrNull()
        if (embeddedVoice == null || tts.setVoice(embeddedVoice) != TextToSpeech.SUCCESS) {
            result.success(false)
            return
        }
        val utteranceId = UUID.randomUUID().toString()
        pendingSpeak = PendingSpeak(utteranceId, result)
        if (tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId) != TextToSpeech.SUCCESS) {
            finishPending(utteranceId, false)
        }
    }

    private fun playBundledHumanRecording(
        assetPath: String,
        result: MethodChannel.Result,
    ) {
        if (!inForeground || !isAllowedBundledNarrationPath(assetPath)) {
            result.success(false)
            return
        }
        stopPending(false)
        val lookupKey = FlutterInjector.instance()
            .flutterLoader()
            .getLookupKeyForAsset(assetPath)
        var temporaryFile: File? = null
        var nativeCallbackCompleted = false
        try {
            // APK内で圧縮される形式でも再生できるよう、固定教材だけをcacheへ一時展開する。
            // 生徒の音声・回答ではない。終了・停止時に必ず削除する。
            val extractedFile = File.createTempFile(
                "dekisugi-narration-",
                ".audio",
                cacheDir,
            )
            temporaryFile = extractedFile
            applicationContext.assets.open(lookupKey).use { input ->
                extractedFile.outputStream().use { output -> input.copyTo(output) }
            }
            val player = MediaPlayer()
            player.setDataSource(extractedFile.absolutePath)
            player.prepare()
            pendingBundledNarration = PendingBundledNarration(
                player = player,
                temporaryFile = extractedFile,
                result = result,
            )
            player.setOnCompletionListener {
                nativeCallbackCompleted = true
                finishBundledNarration(it, true)
            }
            player.setOnErrorListener { failedPlayer, _, _ ->
                nativeCallbackCompleted = true
                finishBundledNarration(failedPlayer, false)
                true
            }
            player.start()
        } catch (_: Exception) {
            if (nativeCallbackCompleted) return
            val pending = pendingBundledNarration
            if (pending != null && pending.temporaryFile == temporaryFile) {
                pendingBundledNarration = null
                pending.player.release()
                pending.temporaryFile.delete()
                pending.result.success(false)
            } else {
                temporaryFile?.delete()
                result.success(false)
            }
        }
    }

    private fun isAllowedBundledNarrationPath(path: String): Boolean {
        return path.matches(
            Regex("^assets/audio/listening/[A-Za-z0-9_-]+[.](m4a|wav)$"),
        )
    }

    private fun finishBundledNarration(player: MediaPlayer, completed: Boolean) {
        runOnUiThread {
            val pending = pendingBundledNarration
            if (pending == null || pending.player !== player) return@runOnUiThread
            pendingBundledNarration = null
            pending.player.release()
            pending.temporaryFile.delete()
            pending.result.success(completed)
        }
    }

    private fun finishPending(utteranceId: String?, completed: Boolean) {
        runOnUiThread {
            val pending = pendingSpeak
            if (pending == null || pending.utteranceId != utteranceId) return@runOnUiThread
            pendingSpeak = null
            pending.result.success(completed)
        }
    }

    private fun stopPending(completed: Boolean) {
        val bundled = pendingBundledNarration
        if (bundled != null) {
            pendingBundledNarration = null
            try {
                bundled.player.stop()
            } catch (_: IllegalStateException) {
                // prepare失敗中でもreleaseとresult完了は続ける。
            }
            bundled.player.release()
            bundled.temporaryFile.delete()
            bundled.result.success(completed)
        }
        textToSpeech?.stop()
        val pending = pendingSpeak ?: return
        pendingSpeak = null
        pending.result.success(completed)
    }

    override fun onStop() {
        inForeground = false
        stopPending(false)
        cancelRecognition("cancelled")
        super.onStop()
    }

    override fun onStart() {
        super.onStart()
        inForeground = true
    }

    override fun onDestroy() {
        stopPending(false)
        cancelRecognition("cancelled")
        textToSpeech?.shutdown()
        textToSpeech = null
        ttsReady = false
        super.onDestroy()
    }
}
