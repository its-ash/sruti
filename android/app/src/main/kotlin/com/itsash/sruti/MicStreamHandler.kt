package com.itsash.sruti

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Streams raw microphone audio for the pitch detector in Dart: mono 16-bit
 * little-endian PCM at 44.1 kHz, in chunks of [CHUNK] samples (about 23 ms).
 * The DSP lives in `lib/core/pitch_detector.dart` so it is unit tested.
 * The caller must hold RECORD_AUDIO; without it a `no_permission` error is sent.
 * Nothing is stored or sent anywhere.
 */
class MicStreamHandler : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private var thread: Thread? = null
    @Volatile private var running = false

    @SuppressLint("MissingPermission")
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val minBuffer = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL, ENCODING)
        if (minBuffer <= 0) {
            events.error("no_mic", "The microphone is not available.", null)
            return
        }
        val record = try {
            AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE, CHANNEL, ENCODING, maxOf(minBuffer, CHUNK * 8))
        } catch (e: SecurityException) {
            events.error("no_permission", "Microphone permission is missing.", null)
            return
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            events.error("no_mic", "The microphone could not be opened.", null)
            return
        }

        running = true
        thread = Thread {
            val buffer = ShortArray(CHUNK)
            record.startRecording()
            try {
                while (running) {
                    val read = record.read(buffer, 0, buffer.size)
                    if (read <= 0) continue
                    val bytes = ByteBuffer.allocate(read * 2).order(ByteOrder.LITTLE_ENDIAN)
                    for (i in 0 until read) bytes.putShort(buffer[i])
                    val data = bytes.array()
                    main.post { if (running) events.success(data) }
                }
            } finally {
                runCatching { record.stop() }
                record.release()
            }
        }.also { it.name = "sruti-mic"; it.start() }
    }

    override fun onCancel(arguments: Any?) {
        running = false
        thread = null
    }

    companion object {
        const val SAMPLE_RATE = 44100
        const val CHUNK = 1024
        private const val CHANNEL = AudioFormat.CHANNEL_IN_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }
}
