package com.google.mediapipe.examples.poselandmarker.training.bridge

import com.google.mediapipe.examples.poselandmarker.training.ExerciseKind

/**
 * Platform-neutral contract reserved for the future Flutter MethodChannel adapter.
 *
 * The classes deliberately expose Map values supported by Flutter's standard codec and do not
 * import Flutter APIs. This keeps the motion module buildable before the Flutter host arrives.
 */
object TrainingBridgeContract {
    const val CHANNEL_NAME = "ai_fitness_coach/training"
    const val METHOD_START_TRAINING = "startTraining"
    const val SCHEMA_VERSION = "1"

    const val ERROR_INVALID_ARGUMENTS = "INVALID_TRAINING_ARGUMENTS"
    const val ERROR_UNSUPPORTED_EXERCISE = "UNSUPPORTED_EXERCISE"
    const val ERROR_CAMERA_PERMISSION_DENIED = "CAMERA_PERMISSION_DENIED"
    const val ERROR_TRAINING_UNAVAILABLE = "TRAINING_UNAVAILABLE"
}

data class TrainingLaunchArgs(
    val sessionId: String,
    val exercise: ExerciseKind,
    val targetReps: Int,
    val schemaVersion: String = TrainingBridgeContract.SCHEMA_VERSION,
) {
    init {
        require(schemaVersion == TrainingBridgeContract.SCHEMA_VERSION) {
            "Unsupported schema_version: $schemaVersion"
        }
        require(sessionId.isNotBlank()) { "session_id must not be blank" }
        require(targetReps > 0) { "target_reps must be greater than zero" }
    }

    fun toMap(): Map<String, Any> = linkedMapOf(
        "schema_version" to schemaVersion,
        "session_id" to sessionId,
        "exercise_id" to exercise.wireValue,
        "target_reps" to targetReps,
    )

    companion object {
        fun fromMap(value: Map<*, *>): TrainingLaunchArgs {
            val schemaVersion = value.requiredString("schema_version")
            val sessionId = value.requiredString("session_id")
            val exerciseId = value.requiredString("exercise_id")
            val exercise = ExerciseKind.values().firstOrNull { it.wireValue == exerciseId }
                ?: throw IllegalArgumentException("Unsupported exercise_id: $exerciseId")
            val targetReps = value.requiredPositiveInt("target_reps")
            return TrainingLaunchArgs(
                schemaVersion = schemaVersion,
                sessionId = sessionId,
                exercise = exercise,
                targetReps = targetReps,
            )
        }
    }
}

enum class TrainingResultStatus(val wireValue: String) {
    COMPLETED("completed"),
    CANCELLED("cancelled"),
}

data class SessionResult(
    val sessionId: String,
    val exercise: ExerciseKind,
    val actualReps: Int,
    val status: TrainingResultStatus,
    val startedAtMs: Long,
    val endedAtMs: Long,
    val durationMs: Long,
    val algorithmVersion: String = "motion_rules_0.1",
    val exerciseSpecVersion: String = "${exercise.wireValue}_0.1",
    val schemaVersion: String = TrainingBridgeContract.SCHEMA_VERSION,
) {
    init {
        require(schemaVersion == TrainingBridgeContract.SCHEMA_VERSION) {
            "Unsupported schema_version: $schemaVersion"
        }
        require(sessionId.isNotBlank()) { "session_id must not be blank" }
        require(actualReps >= 0) { "actual_reps must not be negative" }
        require(startedAtMs >= 0) { "started_at_ms must not be negative" }
        require(endedAtMs >= startedAtMs) { "ended_at_ms must not precede started_at_ms" }
        require(durationMs >= 0) { "duration_ms must not be negative" }
        require(algorithmVersion.isNotBlank()) { "algorithm_version must not be blank" }
        require(exerciseSpecVersion.isNotBlank()) { "exercise_spec_version must not be blank" }
    }

    fun toMap(): Map<String, Any> = linkedMapOf(
        "schema_version" to schemaVersion,
        "session_id" to sessionId,
        "exercise_id" to exercise.wireValue,
        "actual_reps" to actualReps,
        "status" to status.wireValue,
        "started_at_ms" to startedAtMs,
        "ended_at_ms" to endedAtMs,
        "duration_ms" to durationMs,
        "algorithm_version" to algorithmVersion,
        "exercise_spec_version" to exerciseSpecVersion,
    )
}

private fun Map<*, *>.requiredString(key: String): String =
    (this[key] as? String)?.takeIf { it.isNotBlank() }
        ?: throw IllegalArgumentException("$key must be a non-blank string")

private fun Map<*, *>.requiredPositiveInt(key: String): Int {
    val number = this[key] as? Number
        ?: throw IllegalArgumentException("$key must be a positive integer")
    val longValue = number.toLong()
    require(number.toDouble() == longValue.toDouble() && longValue in 1..Int.MAX_VALUE.toLong()) {
        "$key must be a positive integer"
    }
    return longValue.toInt()
}
