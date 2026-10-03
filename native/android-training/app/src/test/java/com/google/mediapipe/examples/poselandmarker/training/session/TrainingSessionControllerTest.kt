package com.google.mediapipe.examples.poselandmarker.training.session

import com.google.mediapipe.examples.poselandmarker.training.ExerciseKind
import com.google.mediapipe.examples.poselandmarker.training.bridge.TrainingLaunchArgs
import com.google.mediapipe.examples.poselandmarker.training.bridge.TrainingMode
import com.google.mediapipe.examples.poselandmarker.training.bridge.TrainingResultStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class TrainingSessionControllerTest {
    private var elapsedMs = 1_000L
    private var wallMs = 10_000L

    private fun controller(targetReps: Int = 5) = TrainingSessionController(
        launchArgs = TrainingLaunchArgs(
            sessionId = "session_test",
            planItemId = "plan_test",
            trainingMode = TrainingMode.PLANNED,
            exercise = ExerciseKind.SQUAT,
            targetSets = 1,
            targetReps = targetReps,
            restSeconds = 0,
            coachName = "AI 私教",
        ),
        elapsedRealtimeMs = { elapsedMs },
        currentTimeMs = { wallMs },
    )

    @Test
    fun pauseTimeIsExcludedFromResultDuration() {
        val controller = controller()
        controller.start()
        elapsedMs += 2_000L
        wallMs += 2_000L
        controller.pause()

        elapsedMs += 5_000L
        wallMs += 5_000L
        assertEquals(2_000L, controller.snapshot().activeDurationMs)
        controller.resume()

        elapsedMs += 3_000L
        wallMs += 3_000L
        val result = controller.complete()

        assertEquals(5_000L, result.durationMs)
        assertEquals(TrainingResultStatus.COMPLETED, result.status)
        assertEquals(TrainingSessionState.COMPLETED, controller.state)
    }

    @Test
    fun resultUsesActualRepetitionsAndReportsTargetReached() {
        val controller = controller(targetReps = 3)
        controller.start()
        controller.updateRepetitions(2)
        assertFalse(controller.snapshot().targetReached)
        controller.updateRepetitions(3)
        assertTrue(controller.snapshot().targetReached)

        val result = controller.complete()

        assertEquals(3, result.actualReps)
    }

    @Test
    fun cancelProducesCancelledResult() {
        val controller = controller()
        controller.start()
        controller.updateRepetitions(2)

        val result = controller.cancel()

        assertEquals(TrainingResultStatus.CANCELLED, result.status)
        assertEquals(2, result.actualReps)
        assertEquals(TrainingSessionState.CANCELLED, controller.state)
    }

    @Test
    fun cancelBeforeCameraStartsHasZeroDuration() {
        val controller = controller()

        val result = controller.cancel()

        assertEquals(TrainingResultStatus.CANCELLED, result.status)
        assertEquals(0L, result.durationMs)
        assertTrue((result.toMap()["exercises"] as List<*>).isEmpty())
    }

    @Test
    fun interruptionBeforeCameraStartsReturnsInterruptedWithoutExercise() {
        val controller = controller()

        val result = controller.interrupt()

        assertEquals(TrainingResultStatus.INTERRUPTED, result.status)
        assertEquals(TrainingSessionState.INTERRUPTED, controller.state)
        assertTrue((result.toMap()["exercises"] as List<*>).isEmpty())
    }

    @Test
    fun repetitionsCannotChangeWhilePaused() {
        val controller = controller()
        controller.start()
        controller.pause()

        assertThrows(IllegalStateException::class.java) {
            controller.updateRepetitions(1)
        }
    }

    @Test
    fun repetitionsCannotDecrease() {
        val controller = controller()
        controller.start()
        controller.updateRepetitions(2)

        assertThrows(IllegalArgumentException::class.java) {
            controller.updateRepetitions(1)
        }
    }

    @Test
    fun terminalSessionCannotResumeOrCompleteAgain() {
        val controller = controller()
        controller.start()
        controller.complete()

        assertThrows(IllegalStateException::class.java) { controller.resume() }
        assertThrows(IllegalStateException::class.java) { controller.complete() }
    }
}
