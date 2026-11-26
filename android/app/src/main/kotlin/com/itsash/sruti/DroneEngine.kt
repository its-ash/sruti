package com.itsash.sruti

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack

/**
 * Plays one seamless loop of 16-bit mono PCM (rendered in Dart by
 * `lib/core/drone.dart`) until stopped. A static-mode [AudioTrack] loops the
 * buffer in the audio hardware path, so the drone does not stutter when the
 * UI is busy. It plays while the app process is alive (no foreground service).
 */
class DroneEngine {
    private var track: AudioTrack? = null
    private var volume = 0.8f

    /** Replaces whatever is playing with [pcm] looped forever. */
    @Synchronized
    fun play(pcm: ByteArray, sampleRate: Int) {
        stop()
        if (pcm.size < 4) return
        val t = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(pcm.size)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
        try {
            t.write(pcm, 0, pcm.size)
            t.setLoopPoints(0, pcm.size / 2, -1)
            t.setVolume(volume)
            t.play()
        } catch (e: RuntimeException) {
            runCatching { t.release() }
            throw e
        }
        track = t
    }

    @Synchronized
    fun setVolume(value: Float) {
        volume = value.coerceIn(0f, 1f)
        track?.setVolume(volume)
    }

    @Synchronized
    fun stop() {
        track?.let {
            runCatching { it.stop() }
            it.release()
        }
        track = null
    }
}
