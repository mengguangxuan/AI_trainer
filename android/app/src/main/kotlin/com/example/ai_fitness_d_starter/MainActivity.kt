package com.example.ai_fitness_d_starter

import android.content.Intent
import com.google.mediapipe.examples.poselandmarker.TrainingActivity
import com.google.mediapipe.examples.poselandmarker.training.bridge.TrainingBridgeContract
import com.google.mediapipe.examples.poselandmarker.training.bridge.TrainingLaunchArgs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var pendingTrainingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TrainingBridgeContract.CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            if (call.method != TrainingBridgeContract.METHOD_START_TRAINING) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            startNativeTraining(call.arguments, result)
        }
    }

    @Suppress("DEPRECATION")
    private fun startNativeTraining(arguments: Any?, result: MethodChannel.Result) {
        if (pendingTrainingResult != null) {
            result.error(
                TrainingBridgeContract.ERROR_TRAINING_IN_PROGRESS,
                "A training session is already active",
                null,
            )
            return
        }

        val args = try {
            val map = arguments as? Map<*, *>
                ?: throw IllegalArgumentException("Training arguments must be a map")
            TrainingLaunchArgs.fromMap(map)
        } catch (error: IllegalArgumentException) {
            result.error(
                TrainingBridgeContract.ERROR_INVALID_ARGUMENTS,
                error.message ?: "Invalid training arguments",
                null,
            )
            return
        }

        pendingTrainingResult = result
        try {
            startActivityForResult(
                TrainingActivity.createIntent(this, args),
                REQUEST_NATIVE_TRAINING,
            )
        } catch (error: RuntimeException) {
            pendingTrainingResult = null
            result.error(
                TrainingBridgeContract.ERROR_TRAINING_UNAVAILABLE,
                error.message ?: "Native training is unavailable",
                null,
            )
        }
    }

    @Deprecated("Activity result API retained for the Flutter v1 bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_NATIVE_TRAINING) return

        val pending = pendingTrainingResult ?: return
        pendingTrainingResult = null

        val errorCode = data?.getStringExtra(TrainingActivity.EXTRA_ERROR_CODE)
        if (errorCode != null) {
            pending.error(
                errorCode,
                data?.getStringExtra(TrainingActivity.EXTRA_ERROR_MESSAGE),
                null,
            )
            return
        }

        val resultJson = data?.getStringExtra(TrainingActivity.EXTRA_RESULT_JSON)
        if (resultJson == null) {
            pending.error(
                TrainingBridgeContract.ERROR_TRAINING_UNAVAILABLE,
                "Native training ended without a result",
                mapOf("activity_result_code" to resultCode),
            )
            return
        }

        try {
            pending.success(jsonObjectToMap(JSONObject(resultJson)))
        } catch (error: RuntimeException) {
            pending.error(
                TrainingBridgeContract.ERROR_TRAINING_UNAVAILABLE,
                "Native training returned malformed data",
                error.message,
            )
        }
    }

    private fun jsonObjectToMap(value: JSONObject): Map<String, Any?> = buildMap {
        value.keys().forEach { key -> put(key, jsonValue(value.get(key))) }
    }

    private fun jsonValue(value: Any?): Any? = when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> jsonObjectToMap(value)
        is JSONArray -> List(value.length()) { index -> jsonValue(value.get(index)) }
        else -> value
    }

    companion object {
        private const val REQUEST_NATIVE_TRAINING = 4101
    }
}
