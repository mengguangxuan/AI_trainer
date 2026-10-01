package com.google.mediapipe.examples.poselandmarker.training.bridge

import com.google.mediapipe.examples.poselandmarker.training.ExerciseKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class TrainingBridgeContractTest {

    @Test
    fun launchArgs_roundTripThroughFlutterCompatibleMap() {
        val args = TrainingLaunchArgs(
            sessionId = "session_001",
            exercise = ExerciseKind.SQUAT,
            targetReps = 10,
        )

        assertEquals(args, TrainingLaunchArgs.fromMap(args.toMap()))
    }

    @Test
    fun launchArgs_acceptsLongFromStandardMessageCodec() {
        val args = TrainingLaunchArgs.fromMap(
            mapOf(
                "schema_version" to "1",
                "session_id" to "session_002",
                "exercise_id" to "push_up",
                "target_reps" to 8L,
            )
        )

        assertEquals(ExerciseKind.PUSH_UP, args.exercise)
        assertEquals(8, args.targetReps)
    }

    @Test
    fun launchArgs_rejectsUnknownExercise() {
        assertThrows(IllegalArgumentException::class.java) {
            TrainingLaunchArgs.fromMap(
                mapOf(
                    "schema_version" to "1",
                    "session_id" to "session_003",
                    "exercise_id" to "burpee",
                    "target_reps" to 10,
                )
            )
        }
    }

    @Test
    fun launchArgs_rejectsNonIntegerTarget() {
        assertThrows(IllegalArgumentException::class.java) {
            TrainingLaunchArgs.fromMap(
                mapOf(
                    "schema_version" to "1",
                    "session_id" to "session_004",
                    "exercise_id" to "squat",
                    "target_reps" to 2.5,
                )
            )
        }
    }

    @Test
    fun sessionResult_serializesMeasuredValues() {
        val result = SessionResult(
            sessionId = "session_005",
            exercise = ExerciseKind.SQUAT,
            actualReps = 8,
            status = TrainingResultStatus.COMPLETED,
            startedAtMs = 1_000L,
            endedAtMs = 43_315L,
        ).toMap()

        assertEquals(8, result["actual_reps"])
        assertEquals("completed", result["status"])
        assertEquals(42_315L, result["duration_ms"])
        assertEquals("squat_0.1", result["exercise_spec_version"])
    }

    @Test
    fun sessionResult_rejectsEndBeforeStart() {
        assertThrows(IllegalArgumentException::class.java) {
            SessionResult(
                sessionId = "session_006",
                exercise = ExerciseKind.PUSH_UP,
                actualReps = 0,
                status = TrainingResultStatus.CANCELLED,
                startedAtMs = 2_000L,
                endedAtMs = 1_000L,
            )
        }
    }
}

