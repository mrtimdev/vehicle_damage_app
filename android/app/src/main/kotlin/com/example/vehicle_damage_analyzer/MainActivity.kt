package com.example.vehicle_damage_analyzer

import android.content.Context
import android.graphics.Bitmap
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.util.Locale
import java.util.UUID

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val channelName = "vehicle_damage_analyzer/tts"
    private val mediaChannelName = "vehicle_damage_analyzer/media"
    private var mediaPlayer: MediaPlayer? = null
    private var pendingMediaResult: MethodChannel.Result? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private var focusRequest: AudioFocusRequest? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tts = TextToSpeech(applicationContext, this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playFile" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_PATH", "Audio file path is empty", null)
                        } else {
                            playAudioFile(path, result)
                        }
                    }
                    "speakNative" -> {
                        val text = call.argument<String>("text") ?: ""
                        val langCode = call.argument<String>("langCode") ?: "en"
                        speakWithNativeTts(text, langCode, result)
                    }
                    "stop" -> {
                        stopAllAudio()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "extractVideoFrames" -> {
                        val videoPath = call.argument<String>("videoPath")
                        val outputDir = call.argument<String>("outputDir")
                        val frameCount = call.argument<Int>("frameCount") ?: 5
                        val maxDimension = call.argument<Int>("maxDimension") ?: 1280
                        val quality = call.argument<Int>("quality") ?: 84
                        if (videoPath.isNullOrBlank() || outputDir.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "videoPath and outputDir are required", null)
                        } else {
                            extractVideoFramesAsync(
                                videoPath = videoPath,
                                outputDir = outputDir,
                                frameCount = frameCount.coerceIn(1, 12),
                                maxDimension = maxDimension.coerceIn(320, 2560),
                                quality = quality.coerceIn(50, 95),
                                result = result
                            )
                        }
                    }
                    "extractAudioTrack" -> {
                        val videoPath = call.argument<String>("videoPath")
                        val outputPath = call.argument<String>("outputPath")
                        if (videoPath.isNullOrBlank() || outputPath.isNullOrBlank()) {
                            result.error("INVALID_ARGS", "videoPath and outputPath are required", null)
                        } else {
                            extractAudioTrackAsync(videoPath, outputPath, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onInit(status: Int) {
        ttsReady = (status == TextToSpeech.SUCCESS)
    }

    private fun ensureAudibleVolumeAndFocus() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val curVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
            if (curVol <= 1 && maxVol > 0) {
                val targetVol = (maxVol * 0.8).toInt().coerceAtLeast(1)
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, 0)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
                val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                    .setAudioAttributes(attrs)
                    .build()
                focusRequest = req
                audioManager.requestAudioFocus(req)
            }
        } catch (_: Exception) {
        }
    }

    private fun abandonFocus() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            }
            focusRequest = null
        } catch (_: Exception) {
        }
    }

    private fun playAudioFile(path: String, result: MethodChannel.Result) {
        stopAllAudio()
        val file = File(path)
        if (!file.exists() || file.length() == 0L) {
            result.error("FILE_NOT_FOUND", "Audio file does not exist: $path", null)
            return
        }

        ensureAudibleVolumeAndFocus()
        pendingMediaResult = result

        try {
            val mp = MediaPlayer()
            mediaPlayer = mp
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            mp.setDataSource(file.absolutePath)
            mp.setVolume(1.0f, 1.0f)
            mp.setOnCompletionListener {
                val res = pendingMediaResult
                pendingMediaResult = null
                releaseMediaPlayer()
                abandonFocus()
                res?.success(true)
            }
            mp.setOnErrorListener { _, what, extra ->
                val res = pendingMediaResult
                pendingMediaResult = null
                releaseMediaPlayer()
                abandonFocus()
                res?.error("MEDIA_PLAYER_ERROR", "MediaPlayer error what=$what extra=$extra", null)
                true
            }
            mp.prepare()
            mp.start()
        } catch (e: Exception) {
            val res = pendingMediaResult
            pendingMediaResult = null
            releaseMediaPlayer()
            abandonFocus()
            res?.error("PLAY_EXCEPTION", e.message, null)
        }
    }

    private fun speakWithNativeTts(text: String, langCode: String, result: MethodChannel.Result) {
        stopAllAudio()
        val engine = tts
        if (!ttsReady || engine == null) {
            result.error("TTS_NOT_READY", "Android TextToSpeech is not initialized", null)
            return
        }

        ensureAudibleVolumeAndFocus()
        val locale = if (langCode == "km") Locale("km", "KH") else Locale.US
        engine.language = locale
        engine.setPitch(1.0f)
        engine.setSpeechRate(0.95f)

        val utteranceId = UUID.randomUUID().toString()
        pendingMediaResult = result

        engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) {}

            override fun onDone(id: String?) {
                if (id == utteranceId) {
                    mainHandler.post {
                        val res = pendingMediaResult
                        pendingMediaResult = null
                        abandonFocus()
                        res?.success(true)
                    }
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onError(id: String?) {
                if (id == utteranceId) {
                    mainHandler.post {
                        val res = pendingMediaResult
                        pendingMediaResult = null
                        abandonFocus()
                        res?.error("TTS_ERROR", "Native TTS utterance error", null)
                    }
                }
            }
        })

        val params = Bundle()
        params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f)
        val speakRes = engine.speak(text, TextToSpeech.QUEUE_FLUSH, params, utteranceId)
        if (speakRes == TextToSpeech.ERROR) {
            val res = pendingMediaResult
            pendingMediaResult = null
            abandonFocus()
            res?.error("TTS_SPEAK_ERROR", "TextToSpeech.speak returned ERROR", null)
        }
    }

    private fun releaseMediaPlayer() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.reset()
                it.release()
            }
        } catch (_: Exception) {
        }
        mediaPlayer = null
    }

    private fun stopAllAudio() {
        val prevRes = pendingMediaResult
        pendingMediaResult = null
        prevRes?.success(false)
        releaseMediaPlayer()
        try {
            tts?.stop()
        } catch (_: Exception) {
        }
        abandonFocus()
    }

    private fun extractVideoFramesAsync(
        videoPath: String,
        outputDir: String,
        frameCount: Int,
        maxDimension: Int,
        quality: Int,
        result: MethodChannel.Result
    ) {
        Thread {
            val retriever = MediaMetadataRetriever()
            val savedPaths = mutableListOf<String>()
            try {
                val videoFile = File(videoPath)
                if (!videoFile.exists() || videoFile.length() == 0L) {
                    mainHandler.post {
                        result.error("VIDEO_NOT_FOUND", "Video file does not exist: $videoPath", null)
                    }
                    return@Thread
                }

                val outFolder = File(outputDir)
                if (!outFolder.exists()) {
                    outFolder.mkdirs()
                }

                retriever.setDataSource(videoFile.absolutePath)
                val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                val durationMs = durationStr?.toLongOrNull()?.coerceAtLeast(500L) ?: 4000L
                val batchTs = System.currentTimeMillis()

                for (i in 0 until frameCount) {
                    val fraction = if (frameCount <= 1) 0.5 else (i + 0.5) / frameCount.toDouble()
                    val timeUs = (durationMs * fraction * 1000.0).toLong().coerceAtLeast(0L)

                    var frame: Bitmap? = try {
                        retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST)
                    } catch (_: Exception) {
                        null
                    }
                    if (frame == null) {
                        frame = try {
                            retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                        } catch (_: Exception) {
                            null
                        }
                    }
                    if (frame == null && i == 0) {
                        frame = try {
                            retriever.getFrameAtTime(0L)
                        } catch (_: Exception) {
                            null
                        }
                    }

                    if (frame != null) {
                        val scaled = scaleBitmapIfNeeded(frame, maxDimension)
                        val outFile = File(outFolder, "vframe_${batchTs}_$i.jpg")
                        FileOutputStream(outFile).use { fos ->
                            scaled.compress(Bitmap.CompressFormat.JPEG, quality, fos)
                            fos.flush()
                        }
                        if (scaled !== frame) {
                            scaled.recycle()
                        }
                        frame.recycle()

                        if (outFile.exists() && outFile.length() > 128L) {
                            savedPaths.add(outFile.absolutePath)
                        }
                    }
                }

                if (savedPaths.isEmpty()) {
                    mainHandler.post {
                        result.error("NO_FRAMES", "Could not decode any video frames from $videoPath", null)
                    }
                } else {
                    mainHandler.post {
                        result.success(savedPaths)
                    }
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("EXTRACT_ERROR", e.message ?: "Failed to extract video frames", null)
                }
            } finally {
                try {
                    retriever.release()
                } catch (_: Exception) {
                }
            }
        }.start()
    }

    private fun scaleBitmapIfNeeded(source: Bitmap, maxDimension: Int): Bitmap {
        val width = source.width
        val height = source.height
        if (width <= maxDimension && height <= maxDimension) {
            return source
        }
        val ratio = width.toFloat() / height.toFloat()
        val targetWidth: Int
        val targetHeight: Int
        if (width >= height) {
            targetWidth = maxDimension
            targetHeight = (maxDimension / ratio).toInt().coerceAtLeast(1)
        } else {
            targetHeight = maxDimension
            targetWidth = (maxDimension * ratio).toInt().coerceAtLeast(1)
        }
        return Bitmap.createScaledBitmap(source, targetWidth, targetHeight, true)
    }

    private fun extractAudioTrackAsync(
        videoPath: String,
        outputPath: String,
        result: MethodChannel.Result
    ) {
        Thread {
            var extractor: MediaExtractor? = null
            var muxer: MediaMuxer? = null
            try {
                val inFile = File(videoPath)
                if (!inFile.exists() || inFile.length() < 1024) {
                    mainHandler.post { result.success(null) }
                    return@Thread
                }

                extractor = MediaExtractor()
                extractor.setDataSource(videoPath)
                var audioTrackIndex = -1
                var audioFormat: MediaFormat? = null

                for (i in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(i)
                    val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                    if (mime.startsWith("audio/")) {
                        audioTrackIndex = i
                        audioFormat = format
                        break
                    }
                }

                if (audioTrackIndex < 0 || audioFormat == null) {
                    mainHandler.post { result.success(null) }
                    return@Thread
                }

                extractor.selectTrack(audioTrackIndex)
                val outFile = File(outputPath)
                outFile.parentFile?.mkdirs()
                if (outFile.exists()) outFile.delete()

                muxer = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                val muxerTrackIndex = muxer.addTrack(audioFormat)
                muxer.start()

                val maxBufferSize = if (audioFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    audioFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
                } else {
                    256 * 1024
                }
                val buffer = ByteBuffer.allocate(maxBufferSize.coerceAtLeast(64 * 1024))
                val bufferInfo = MediaCodec.BufferInfo()

                while (true) {
                    bufferInfo.offset = 0
                    bufferInfo.size = extractor.readSampleData(buffer, 0)
                    if (bufferInfo.size < 0) {
                        break
                    }
                    bufferInfo.presentationTimeUs = extractor.sampleTime
                    bufferInfo.flags = extractor.sampleFlags
                    muxer.writeSampleData(muxerTrackIndex, buffer, bufferInfo)
                    extractor.advance()
                }

                muxer.stop()
                muxer.release()
                muxer = null
                extractor.release()
                extractor = null

                mainHandler.post {
                    if (outFile.exists() && outFile.length() > 256) {
                        result.success(outFile.absolutePath)
                    } else {
                        result.success(null)
                    }
                }
            } catch (e: Exception) {
                try { muxer?.release() } catch (_: Exception) {}
                try { extractor?.release() } catch (_: Exception) {}
                mainHandler.post { result.success(null) }
            }
        }.start()
    }

    override fun onDestroy() {
        stopAllAudio()
        try {
            tts?.shutdown()
        } catch (_: Exception) {
        }
        tts = null
        super.onDestroy()
    }
}
