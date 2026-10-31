package `in`.vylithra.app

import android.os.Build
import android.os.Bundle
import android.view.Display
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    private val DISPLAY_CHANNEL = "in.vylithra.app/display"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setHighRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        flutterEngine.plugins.add(VideoEncoderPlugin())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISPLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getRefreshRate" -> {
                    val rate = getDisplayRefreshRate()
                    result.success(rate.toDouble())
                }
                "getSupportedRefreshRates" -> {
                    val rates = getSupportedRefreshRates()
                    result.success(rates)
                }
                "setRefreshRateMode" -> {
                    val mode = call.argument<String>("mode") ?: "high"
                    val success = applyRefreshRateMode(mode)
                    result.success(success)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setHighRefreshRate() {
        applyRefreshRateMode("high")
    }

    private fun getDisplayRefreshRate(): Float {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display?.refreshRate ?: 60.0f
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.refreshRate
        }
    }

    private fun getSupportedRefreshRates(): List<Double> {
        val rates = mutableSetOf<Double>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val displayObj = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay
            }
            displayObj?.supportedModes?.forEach { mode ->
                rates.add(mode.refreshRate.toDouble())
            }
        }
        if (rates.isEmpty()) {
            rates.add(60.0)
        }
        return rates.sorted()
    }

    private fun applyRefreshRateMode(mode: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val displayObj = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                } ?: return false

                val modes = displayObj.supportedModes ?: return false
                val params = window.attributes

                when (mode.lowercase()) {
                    "standard", "60" -> {
                        val mode60 = modes.minByOrNull { kotlin.math.abs(it.refreshRate - 60f) }
                        if (mode60 != null) {
                            params.preferredDisplayModeId = mode60.modeId
                            window.attributes = params
                            return true
                        }
                    }
                    "90" -> {
                        val mode90 = modes.minByOrNull { kotlin.math.abs(it.refreshRate - 90f) }
                        if (mode90 != null) {
                            params.preferredDisplayModeId = mode90.modeId
                            window.attributes = params
                            return true
                        }
                    }
                    else -> {
                        val maxMode = modes.maxByOrNull { it.refreshRate }
                        if (maxMode != null) {
                            params.preferredDisplayModeId = maxMode.modeId
                            window.attributes = params
                            return true
                        }
                    }
                }
            } catch (e: Exception) {
                return false
            }
        }
        return false
    }
}
