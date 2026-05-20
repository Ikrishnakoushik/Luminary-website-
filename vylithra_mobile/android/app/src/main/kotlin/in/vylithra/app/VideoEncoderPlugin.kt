package `in`.vylithra.app

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class VideoEncoderPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var openGLRenderer: OpenGLRenderer? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "vylithra/video_encoder")
        channel.setMethodCallHandler(this)
        openGLRenderer = OpenGLRenderer()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startRecording" -> {
                // TODO: Initialize MediaCodec and start the OpenGL EGL Surface loop
                // val bgImage = call.argument<String>("backgroundImage")
                openGLRenderer?.startRecording()
                result.success(true)
            }
            "stopRecording" -> {
                // TODO: Stop MediaCodec, drain muxer, and return the final MP4 path
                val outputPath = openGLRenderer?.stopRecording() ?: ""
                result.success(outputPath)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        openGLRenderer?.release()
        openGLRenderer = null
    }
}
