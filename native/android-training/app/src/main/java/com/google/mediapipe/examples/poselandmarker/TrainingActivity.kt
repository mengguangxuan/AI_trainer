package com.google.mediapipe.examples.poselandmarker

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import android.view.View
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.navigation.fragment.NavHostFragment
import androidx.navigation.ui.setupWithNavController
import com.google.mediapipe.examples.poselandmarker.databinding.ActivityMainBinding
import com.google.mediapipe.examples.poselandmarker.training.ExerciseKind
import com.google.mediapipe.examples.poselandmarker.training.TrainingSnapshot
import com.google.mediapipe.examples.poselandmarker.training.bridge.SessionResult
import com.google.mediapipe.examples.poselandmarker.training.bridge.TrainingBridgeContract
import com.google.mediapipe.examples.poselandmarker.training.bridge.TrainingLaunchArgs
import com.google.mediapipe.examples.poselandmarker.training.bridge.TrainingResultStatus
import com.google.mediapipe.examples.poselandmarker.training.session.TrainingSessionController
import com.google.mediapipe.examples.poselandmarker.training.session.TrainingSessionSnapshot
import com.google.mediapipe.examples.poselandmarker.training.session.TrainingSessionState
import org.json.JSONObject

/**
 * Full-screen native training host that can run standalone or be launched by a Flutter gateway.
 *
 * Flutter-specific MethodChannel code will live in the future Flutter MainActivity. It only needs
 * to translate a Map into [createIntent] extras and translate the returned extras back into a Map.
 */
open class TrainingActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding

    lateinit var launchArgs: TrainingLaunchArgs
        private set

    var allowsExerciseSwitching: Boolean = false
        private set

    private lateinit var sessionController: TrainingSessionController
    private var pausedByLifecycle = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val parsedArgs = runCatching { parseLaunchArgs(intent) }
        if (parsedArgs.isFailure) {
            finishWithError(
                code = TrainingBridgeContract.ERROR_INVALID_ARGUMENTS,
                message = parsedArgs.exceptionOrNull()?.message ?: "Invalid training arguments",
            )
            return
        }
        launchArgs = parsedArgs.getOrThrow()
        allowsExerciseSwitching = !hasExternalLaunchArgs(intent)
        startNewSession(launchArgs)

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val navHostFragment =
            supportFragmentManager.findFragmentById(R.id.fragment_container) as NavHostFragment
        binding.navigation.setupWithNavController(navHostFragment.navController)
        binding.navigation.setOnNavigationItemReselectedListener { }

        if (!allowsExerciseSwitching) {
            binding.navigation.visibility = View.GONE
            binding.toolbar.visibility = View.GONE
            binding.view.visibility = View.GONE
        }
    }

    fun sessionSnapshot(): TrainingSessionSnapshot = sessionController.snapshot()

    fun ensureSessionStarted(): TrainingSessionSnapshot {
        if (sessionController.state == TrainingSessionState.PREPARING) {
            sessionController.start()
        }
        return sessionController.snapshot()
    }

    fun isTrainingActive(): Boolean =
        sessionController.state == TrainingSessionState.ACTIVE

    fun onTrainingSnapshot(snapshot: TrainingSnapshot) {
        sessionController.updateRepetitionsIfActive(snapshot.repetitions)
    }

    fun togglePause(): TrainingSessionSnapshot {
        when (sessionController.state) {
            TrainingSessionState.ACTIVE -> sessionController.pause()
            TrainingSessionState.PAUSED -> sessionController.resume()
            else -> Unit
        }
        return sessionController.snapshot()
    }

    fun restartDemoSession(exercise: ExerciseKind) {
        check(allowsExerciseSwitching) { "Exercise switching is disabled for launched sessions" }
        launchArgs = TrainingLaunchArgs(
            sessionId = "local-prototype-${System.currentTimeMillis()}",
            exercise = exercise,
            targetReps = DEFAULT_TARGET_REPS,
        )
        startNewSession(launchArgs)
        ensureSessionStarted()
    }

    fun completeTraining() {
        if (sessionController.state !in setOf(
                TrainingSessionState.ACTIVE,
                TrainingSessionState.PAUSED,
            )
        ) return
        finishWithResult(sessionController.complete())
    }

    fun requestCancelTraining() {
        if (sessionController.state !in setOf(
                TrainingSessionState.PREPARING,
                TrainingSessionState.ACTIVE,
                TrainingSessionState.PAUSED,
            )
        ) {
            finish()
            return
        }
        AlertDialog.Builder(this)
            .setTitle(R.string.cancel_training_title)
            .setMessage(R.string.cancel_training_message)
            .setNegativeButton(R.string.action_continue_training, null)
            .setPositiveButton(R.string.action_confirm_cancel) { _, _ -> cancelTraining() }
            .show()
    }

    fun onCameraPermissionDenied() {
        if (!allowsExerciseSwitching) {
            finishWithError(
                code = TrainingBridgeContract.ERROR_CAMERA_PERMISSION_DENIED,
                message = "Camera permission was denied",
            )
        }
    }

    @Deprecated("Deprecated in Android SDK, retained for the standalone prototype")
    override fun onBackPressed() {
        requestCancelTraining()
    }

    override fun onStop() {
        super.onStop()
        if (
            this::sessionController.isInitialized &&
            !isChangingConfigurations &&
            sessionController.state == TrainingSessionState.ACTIVE
        ) {
            sessionController.pause()
            pausedByLifecycle = true
        }
    }

    override fun onStart() {
        super.onStart()
        if (
            this::sessionController.isInitialized &&
            pausedByLifecycle &&
            sessionController.state == TrainingSessionState.PAUSED
        ) {
            sessionController.resume()
            pausedByLifecycle = false
        }
    }

    private fun cancelTraining() {
        if (sessionController.state in setOf(
                TrainingSessionState.PREPARING,
                TrainingSessionState.ACTIVE,
                TrainingSessionState.PAUSED,
            )
        ) {
            finishWithResult(sessionController.cancel())
        } else {
            finish()
        }
    }

    private fun startNewSession(args: TrainingLaunchArgs) {
        sessionController = TrainingSessionController(
            launchArgs = args,
            elapsedRealtimeMs = SystemClock::elapsedRealtime,
            currentTimeMs = System::currentTimeMillis,
        )
        pausedByLifecycle = false
    }

    private fun finishWithResult(result: SessionResult) {
        val data = Intent().apply {
            result.toMap().forEach { (key, value) ->
                when (value) {
                    is String -> putExtra(key, value)
                    is Int -> putExtra(key, value)
                    is Long -> putExtra(key, value)
                }
            }
        }
        val resultCode = if (result.status == TrainingResultStatus.COMPLETED) {
            Activity.RESULT_OK
        } else {
            Activity.RESULT_CANCELED
        }
        Log.i(SESSION_EVENT_TAG, JSONObject(result.toMap()).toString())
        setResult(resultCode, data)
        finish()
    }

    private fun finishWithError(code: String, message: String) {
        setResult(
            Activity.RESULT_CANCELED,
            Intent()
                .putExtra(EXTRA_ERROR_CODE, code)
                .putExtra(EXTRA_ERROR_MESSAGE, message),
        )
        finish()
    }

    private fun parseLaunchArgs(value: Intent): TrainingLaunchArgs {
        if (!hasExternalLaunchArgs(value)) {
            return TrainingLaunchArgs(
                sessionId = "local-prototype-${System.currentTimeMillis()}",
                exercise = ExerciseKind.SQUAT,
                targetReps = DEFAULT_TARGET_REPS,
            )
        }
        return TrainingLaunchArgs.fromMap(
            mapOf(
                "schema_version" to value.getStringExtra(EXTRA_SCHEMA_VERSION),
                "session_id" to value.getStringExtra(EXTRA_SESSION_ID),
                "exercise_id" to value.getStringExtra(EXTRA_EXERCISE_ID),
                "target_reps" to value.getIntExtra(EXTRA_TARGET_REPS, 0),
            )
        )
    }

    private fun hasExternalLaunchArgs(value: Intent): Boolean =
        value.hasExtra(EXTRA_SESSION_ID) ||
            value.hasExtra(EXTRA_EXERCISE_ID) ||
            value.hasExtra(EXTRA_TARGET_REPS) ||
            value.hasExtra(EXTRA_SCHEMA_VERSION)

    companion object {
        const val EXTRA_SCHEMA_VERSION = "schema_version"
        const val EXTRA_SESSION_ID = "session_id"
        const val EXTRA_EXERCISE_ID = "exercise_id"
        const val EXTRA_TARGET_REPS = "target_reps"
        const val EXTRA_ERROR_CODE = "error_code"
        const val EXTRA_ERROR_MESSAGE = "error_message"

        private const val DEFAULT_TARGET_REPS = 10
        private const val SESSION_EVENT_TAG = "FitnessCoachSession"

        fun createIntent(context: Context, args: TrainingLaunchArgs): Intent =
            Intent(context, TrainingActivity::class.java).apply {
                putExtra(EXTRA_SCHEMA_VERSION, args.schemaVersion)
                putExtra(EXTRA_SESSION_ID, args.sessionId)
                putExtra(EXTRA_EXERCISE_ID, args.exercise.wireValue)
                putExtra(EXTRA_TARGET_REPS, args.targetReps)
            }
    }
}
