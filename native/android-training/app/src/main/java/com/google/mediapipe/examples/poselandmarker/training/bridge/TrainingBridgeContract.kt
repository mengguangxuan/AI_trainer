package com.google.mediapipe.examples.poselandmarker.training.bridge

import com.google.mediapipe.examples.poselandmarker.training.ExerciseKind
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/** The frozen v1 boundary shared by Flutter and the native Android trainer. */
object TrainingBridgeContract {
    const val CHANNEL_NAME = "ai_fitness/training_v1"
    const val METHOD_START_TRAINING = "startTraining"
    const val SCHEMA_VERSION = 1

    const val ERROR_INVALID_ARGUMENTS = "invalid_arguments"
    const val ERROR_TRAINING_UNAVAILABLE = "training_unavailable"
    const val ERROR_TRAINING_IN_PROGRESS = "training_in_progress"
}

enum class TrainingMode(val wireValue: String) {
    PLANNED("planned"),
    FREE("free"),
}

/**
 * Android's normalized form of D's TrainingLaunchArgs.
 *
 * The external `exercises` list is restricted to exactly one item in v1. A session id is generated
 * on Android because D's launch structure intentionally does not contain one.
 */
data class TrainingLaunchArgs(
    val sessionId: String,
    val planItemId: String?,
    val trainingMode: TrainingMode,
    val exercise: ExerciseKind,
    val targetSets: Int,
    val targetReps: Int,
    val restSeconds: Int,
    val coachName: String,
    val schemaVersion: Int = TrainingBridgeContract.SCHEMA_VERSION,
) {
    init {
        require(schemaVersion == TrainingBridgeContract.SCHEMA_VERSION) {
            "Unsupported schema_version: $schemaVersion"
        }
        require(sessionId.isNotBlank()) { "session_id must not be blank" }
        require(planItemId == null || planItemId.isNotBlank()) {
            "plan_item_id must be null or a non-blank string"
        }
        require(targetSets == 1) { "target_sets must be 1 in v1" }
        require(targetReps > 0) { "target_reps must be greater than zero" }
        require(restSeconds >= 0) { "rest_seconds must not be negative" }
        require(coachName.isNotBlank()) { "coach_name must not be blank" }
    }

    fun toMap(): Map<String, Any?> = linkedMapOf(
        "schema_version" to schemaVersion,
        "plan_item_id" to planItemId,
        "training_mode" to trainingMode.wireValue,
        "exercises" to listOf(
            linkedMapOf(
                "exercise_id" to exercise.wireValue,
                "target_sets" to targetSets,
                "target_reps" to targetReps,
                "rest_seconds" to restSeconds,
            )
        ),
        "coach_name" to coachName,
    )

    companion object {
        fun fromMap(
            value: Map<*, *>,
            sessionIdFactory: () -> String = { UUID.randomUUID().toString() },
        ): TrainingLaunchArgs {
            val schemaVersion = value.requiredInt("schema_version")
            val planItemId = value.optionalString("plan_item_id")
            val trainingModeValue = value.requiredString("training_mode")
            val trainingMode = TrainingMode.values().firstOrNull {
                it.wireValue == trainingModeValue
            } ?: throw IllegalArgumentException(
                "training_mode must be planned or free"
            )
            val exercises = value["exercises"] as? List<*>
                ?: throw IllegalArgumentException("exercises must be a list")
            require(exercises.size == 1) { "exercises must contain exactly one item in v1" }
            val exerciseMap = exercises.single() as? Map<*, *>
                ?: throw IllegalArgumentException("exercises[0] must be a map")
            val exerciseId = exerciseMap.requiredString("exercise_id")
            val exercise = ExerciseKind.values().firstOrNull { it.wireValue == exerciseId }
                ?: throw IllegalArgumentException("Unsupported exercise_id: $exerciseId")

            return TrainingLaunchArgs(
                schemaVersion = schemaVersion,
                sessionId = sessionIdFactory().also {
                    require(it.isNotBlank()) { "Generated session_id must not be blank" }
                },
                planItemId = planItemId,
                trainingMode = trainingMode,
                exercise = exercise,
                targetSets = exerciseMap.requiredInt("target_sets"),
                targetReps = exerciseMap.requiredInt("target_reps"),
                restSeconds = exerciseMap.requiredNonNegativeInt("rest_seconds"),
                coachName = value.requiredString("coach_name"),
            )
        }
    }
}

enum class TrainingResultStatus(val wireValue: String) {
    COMPLETED("completed"),
    CANCELLED("cancelled"),
    INTERRUPTED("interrupted"),
}

/** Measured native result serialized into D's frozen SessionResult shape. */
data class SessionResult(
    val sessionId: String,
    val exercise: ExerciseKind,
    val actualReps: Int,
    val targetReps: Int,
    val status: TrainingResultStatus,
    val finishedAtMs: Long,
    val durationMs: Long,
    val includeExercise: Boolean = true,
    val schemaVersion: Int = TrainingBridgeContract.SCHEMA_VERSION,
) {
    init {
        require(schemaVersion == TrainingBridgeContract.SCHEMA_VERSION) {
            "Unsupported schema_version: $schemaVersion"
        }
        require(sessionId.isNotBlank()) { "session_id must not be blank" }
        require(actualReps >= 0) { "completed_reps must not be negative" }
        require(targetReps > 0) { "target_reps must be greater than zero" }
        require(finishedAtMs >= 0) { "finished_at must not be negative" }
        require(durationMs >= 0) { "duration must not be negative" }
        require(status != TrainingResultStatus.COMPLETED || includeExercise) {
            "completed result must contain an exercise"
        }
    }

    val durationSeconds: Int
        get() = (durationMs / 1_000L).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()

    fun toMap(): Map<String, Any?> = linkedMapOf(
        "schema_version" to schemaVersion,
        "session_id" to sessionId,
        "status" to status.wireValue,
        "finished_at" to formatIso8601(finishedAtMs),
        "duration_seconds" to durationSeconds,
        "exercises" to if (includeExercise) {
            listOf(
                linkedMapOf<String, Any?>(
                    "exercise_id" to exercise.wireValue,
                    "completed_sets" to if (
                        status == TrainingResultStatus.COMPLETED && actualReps >= targetReps
                    ) 1 else 0,
                    "completed_reps" to actualReps,
                    "quality_trend" to null,
                    "main_error_code" to null,
                )
            )
        } else {
            emptyList<Map<String, Any?>>()
        },
        "agent_summary" to null,
        "next_plan_changed" to false,
        "source" to "real",
    )
}

private fun formatIso8601(epochMs: Long): String =
    SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US).apply {
        timeZone = TimeZone.getDefault()
    }.format(Date(epochMs))

private fun Map<*, *>.requiredString(key: String): String =
    (this[key] as? String)?.takeIf { it.isNotBlank() }
        ?: throw IllegalArgumentException("$key must be a non-blank string")

private fun Map<*, *>.optionalString(key: String): String? {
    val value = this[key] ?: return null
    return (value as? String)?.takeIf { it.isNotBlank() }
        ?: throw IllegalArgumentException("$key must be null or a non-blank string")
}

private fun Map<*, *>.requiredInt(key: String): Int = requiredInteger(key, minimum = 1)

private fun Map<*, *>.requiredNonNegativeInt(key: String): Int =
    requiredInteger(key, minimum = 0)

private fun Map<*, *>.requiredInteger(key: String, minimum: Int): Int {
    val number = this[key] as? Number
        ?: throw IllegalArgumentException("$key must be an integer")
    val longValue = number.toLong()
    require(
        number.toDouble() == longValue.toDouble() &&
            longValue in minimum.toLong()..Int.MAX_VALUE.toLong()
    ) {
        "$key must be an integer greater than or equal to $minimum"
    }
    return longValue.toInt()
}
