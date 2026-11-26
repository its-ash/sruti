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
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Streams raw microphone audio for the pitch detector in Dart: mono 16-bit
 * little-endian PCM at 44.1 kHz, in chunks of [CHUNK] samples (about 23 ms).
 * The DSP lives in `lib/core/pitch_detector.dart` so it is unit tested.
 * The caller must hold RECORD_AUDIO; without it a `no_permission` error is sent.
 * Nothing is stored or sent anywhere.
 */
class MicStreamHandler : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private var active: AtomicBoolean? = null
    private var record: AudioRecord? = null
    private var thread: Thread? = null

    @Synchronized
    @SuppressLint("MissingPermission")
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stop()
        val minBuffer = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL, ENCODING)
        if (minBuffer <= 0) {
            events.error("no_mic", "The microphone is not available.", null)
            return
        }
        val rec = try {
            AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE, CHANNEL, ENCODING, maxOf(minBuffer, CHUNK * 8))
        } catch (e: SecurityException) {
            events.error("no_permission", "Microphone permission is missing.", null)
            return
        }
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            rec.release()
            events.error("no_mic", "The microphone could not be opened.", null)
            return
        }

        val session = AtomicBoolean(true)
        active = session
        record = rec
        thread = Thread {
            val buffer = ShortArray(CHUNK)
            try {
                rec.startRecording()
                while (session.get()) {
                    val read = rec.read(buffer, 0, buffer.size)
                    if (read < 0) break
                    if (read == 0) continue
                    val bytes = ByteBuffer.allocate(read * 2).order(ByteOrder.LITTLE_ENDIAN)
                    for (i in 0 until read) bytes.putShort(buffer[i])
                    val data = bytes.array()
                    main.post { if (session.get()) events.success(data) }
                }
            } catch (_: Exception) {
                main.post { if (session.get()) events.error("no_mic", "The microphone could not be started.", null) }
            } finally {
                runCatching { rec.stop() }
                rec.release()
            }
        }.also { it.name = "sruti-mic"; it.start() }
    }

    override fun onCancel(arguments: Any?) {
        stop()
    }

    @Synchronized
    fun stop() {
        active?.set(false)
        active = null
        runCatching { record?.stop() }
        record = null
        val t = thread
        thread = null
        if (t != null && t !== Thread.currentThread()) {
            runCatching { t.join(500) }
        }
    }

    companion object {
        const val SAMPLE_RATE = 44100
        const val CHUNK = 1024
        private const val CHANNEL = AudioFormat.CHANNEL_IN_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }
}
