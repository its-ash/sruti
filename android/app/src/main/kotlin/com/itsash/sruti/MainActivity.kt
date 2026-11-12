package com.itsash.sruti

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Wires Dart to the microphone and the drone player.
 *
 * Channels (names match `lib/platform/audio_channel.dart`):
 * - `com.itsash.sruti/mic` (events): 16-bit mono PCM chunks at 44.1 kHz.
 * - `com.itsash.sruti/drone` (method): `play {pcm, sampleRate}`, `volume`, `stop`,
 *   `keepScreenOn`.
 */
class MainActivity : FlutterActivity() {
    private val drone = DroneEngine()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "$CHANNEL/mic").setStreamHandler(MicStreamHandler())

        MethodChannel(messenger, "$CHANNEL/drone").setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val pcm = call.argument<ByteArray>("pcm")
                    val rate = call.argument<Int>("sampleRate") ?: 22050
                    if (pcm == null) {
                        result.error("bad_args", "pcm is missing", null)
                    } else {
                        drone.play(pcm, rate)
                        result.success(null)
                    }
                }
                "volume" -> {
                    drone.setVolume((call.arguments as? Number)?.toFloat() ?: 0.8f)
                    result.success(null)
                }
                "stop" -> {
                    drone.stop()
                    result.success(null)
                }
                "keepScreenOn" -> {
                    if (call.arguments as? Boolean == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        drone.stop()
        super.onDestroy()
    }

    private companion object {
        const val CHANNEL = "com.itsash.sruti"
    }
}
