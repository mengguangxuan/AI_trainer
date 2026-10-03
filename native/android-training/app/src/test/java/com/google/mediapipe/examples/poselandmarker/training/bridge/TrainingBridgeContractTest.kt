package com.google.mediapipe.examples.poselandmarker.training.bridge

import com.google.mediapipe.examples.poselandmarker.training.ExerciseKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class TrainingBridgeContractTest {
    private val launchMap: Map<String, Any?> = mapOf(
        "schema_version" to 1,
        "plan_item_id" to "squat_01",
        "training_mode" to "planned",
        "exercises" to listOf(
            mapOf(
                "exercise_id" to "squat",
                "target_sets" to 1,
                "target_reps" to 6,
                "rest_seconds" to 45,
            )
        ),
        "coach_name" to "AI 私教",
    )

    @Test
    fun launchArgs_decodesDartV1AndRoundTripsExternalShape() {
        val args = TrainingLaunchArgs.fromMap(launchMap) { "session_001" }

        assertEquals("session_001", args.sessionId)
        assertEquals(ExerciseKind.SQUAT, args.exercise)
        assertEquals(6, args.targetReps)
        assertEquals(launchMap, args.toMap())
    }

    @Test
    fun launchArgs_acceptsLongsFromStandardMessageCodec() {
        val input = launchMap.toMutableMap().apply {
            this["exercises"] = listOf(
                mapOf(
                    "exercise_id" to "push_up",
                    "target_sets" to 1L,
                    "target_reps" to 8L,
                    "rest_seconds" to 0L,
                )
            )
            this["plan_item_id"] = null
            this["training_mode"] = "free"
        }

        val args = TrainingLaunchArgs.fromMap(input) { "session_002" }

        assertEquals(ExerciseKind.PUSH_UP, args.exercise)
        assertEquals(TrainingMode.FREE, args.trainingMode)
        assertNull(args.planItemId)
    }

    @Test
    fun launchArgs_rejectsStringSchemaVersion() {
        assertThrows(IllegalArgumentException::class.java) {
            TrainingLaunchArgs.fromMap(launchMap + ("schema_version" to "1"))
        }
    }

    @Test
    fun launchArgs_rejectsMultipleExercisesAndMultipleSets() {
        val exercise = (launchMap["exercises"] as List<*>).single()
        assertThrows(IllegalArgumentException::class.java) {
            TrainingLaunchArgs.fromMap(launchMap + ("exercises" to listOf(exercise, exercise)))
        }
        assertThrows(IllegalArgumentException::class.java) {
            TrainingLaunchArgs.fromMap(
                launchMap + ("exercises" to listOf(
                    (exercise as Map<*, *>) + ("target_sets" to 2)
                ))
            )
        }
    }

    @Test
    fun launchArgs_rejectsPushupAlias() {
        val exercise = (launchMap["exercises"] as List<Map<String, Any>>).single()
        assertThrows(IllegalArgumentException::class.java) {
            TrainingLaunchArgs.fromMap(
                launchMap + ("exercises" to listOf(exercise + ("exercise_id" to "pushup")))
            )
        }
    }

    @Test
    fun completedResult_serializesFrozenDartShape() {
        val result = SessionResult(
            sessionId = "session_005",
            exercise = ExerciseKind.SQUAT,
            actualReps = 8,
            targetReps = 6,
            status = TrainingResultStatus.COMPLETED,
            finishedAtMs = 1_790_841_642_315L,
            durationMs = 40_999L,
        ).toMap()

        assertEquals(1, result["schema_version"])
        assertEquals("completed", result["status"])
        assertEquals(40, result["duration_seconds"])
        assertEquals("real", result["source"])
        assertNull(result["agent_summary"])
        assertEquals(false, result["next_plan_changed"])
        val exercise = (result["exercises"] as List<Map<String, Any?>>).single()
        assertEquals("squat", exercise["exercise_id"])
        assertEquals(1, exercise["completed_sets"])
        assertEquals(8, exercise["completed_reps"])
        assertNull(exercise["quality_trend"])
        assertNull(exercise["main_error_code"])
    }

    @Test
    fun earlyCompletionDoesNotClaimACompletedSet() {
        val result = SessionResult(
            sessionId = "session_006",
            exercise = ExerciseKind.PUSH_UP,
            actualReps = 3,
            targetReps = 8,
            status = TrainingResultStatus.COMPLETED,
            finishedAtMs = 2_000L,
            durationMs = 1_000L,
        ).toMap()

        val exercise = (result["exercises"] as List<Map<String, Any?>>).single()
        assertEquals(0, exercise["completed_sets"])
        assertEquals(3, exercise["completed_reps"])
    }

    @Test
    fun interruptionBeforeStartMayReturnNoExercise() {
        val result = SessionResult(
            sessionId = "session_007",
            exercise = ExerciseKind.SQUAT,
            actualReps = 0,
            targetReps = 6,
            status = TrainingResultStatus.INTERRUPTED,
            finishedAtMs = 2_000L,
            durationMs = 0L,
            includeExercise = false,
        ).toMap()

        assertEquals("interrupted", result["status"])
        assertEquals(emptyList<Any>(), result["exercises"])
    }
}
