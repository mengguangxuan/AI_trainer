package com.google.mediapipe.examples.poselandmarker.training.session

import com.google.mediapipe.examples.poselandmarker.training.bridge.SessionResult
import com.google.mediapipe.examples.poselandmarker.training.bridge.TrainingLaunchArgs
import com.google.mediapipe.examples.poselandmarker.training.bridge.TrainingResultStatus

enum class TrainingSessionState {
    PREPARING,
    ACTIVE,
    PAUSED,
    COMPLETED,
    CANCELLED,
}

data class TrainingSessionSnapshot(
    val state: TrainingSessionState,
    val repetitions: Int,
    val targetReps: Int,
    val targetReached: Boolean,
    val activeDurationMs: Long,
)

/**
 * Owns the lifecycle and result of one single-exercise training session.
 *
 * Duration uses a monotonic clock and excludes pauses. Wall-clock values are captured separately
 * for protocol timestamps. The controller has no Android or Flutter dependencies.
 */
class TrainingSessionController(
    val launchArgs: TrainingLaunchArgs,
    private val elapsedRealtimeMs: () -> Long,
    private val currentTimeMs: () -> Long,
) {
    var state: TrainingSessionState = TrainingSessionState.PREPARING
        private set

    var repetitions: Int = 0
        private set

    private var startedAtWallMs: Long? = null
    private var startedAtElapsedMs: Long? = null
    private var pauseStartedAtElapsedMs: Long? = null
    private var totalPausedMs: Long = 0L

    @Synchronized
    fun start() {
        check(state == TrainingSessionState.PREPARING) {
            "Session can only start from PREPARING"
        }
        startedAtWallMs = currentTimeMs()
        startedAtElapsedMs = elapsedRealtimeMs()
        state = TrainingSessionState.ACTIVE
    }

    @Synchronized
    fun updateRepetitions(value: Int) {
        check(state == TrainingSessionState.ACTIVE) {
            "Repetitions can only change while the session is ACTIVE"
        }
        require(value >= repetitions) { "Repetitions must not decrease" }
        repetitions = value
    }

    @Synchronized
    fun updateRepetitionsIfActive(value: Int): Boolean {
        if (state != TrainingSessionState.ACTIVE) return false
        require(value >= repetitions) { "Repetitions must not decrease" }
        repetitions = value
        return true
    }

    @Synchronized
    fun pause() {
        check(state == TrainingSessionState.ACTIVE) {
            "Session can only pause from ACTIVE"
        }
        pauseStartedAtElapsedMs = elapsedRealtimeMs()
        state = TrainingSessionState.PAUSED
    }

    @Synchronized
    fun resume() {
        check(state == TrainingSessionState.PAUSED) {
            "Session can only resume from PAUSED"
        }
        val pauseStarted = checkNotNull(pauseStartedAtElapsedMs)
        totalPausedMs += (elapsedRealtimeMs() - pauseStarted).coerceAtLeast(0L)
        pauseStartedAtElapsedMs = null
        state = TrainingSessionState.ACTIVE
    }

    @Synchronized
    fun complete(): SessionResult = finish(TrainingResultStatus.COMPLETED)

    @Synchronized
    fun cancel(): SessionResult {
        if (state == TrainingSessionState.PREPARING) {
            val nowWall = currentTimeMs()
            state = TrainingSessionState.CANCELLED
            return SessionResult(
                sessionId = launchArgs.sessionId,
                exercise = launchArgs.exercise,
                actualReps = 0,
                status = TrainingResultStatus.CANCELLED,
                startedAtMs = nowWall,
                endedAtMs = nowWall,
                durationMs = 0L,
            )
        }
        return finish(TrainingResultStatus.CANCELLED)
    }

    @Synchronized
    fun snapshot(): TrainingSessionSnapshot = TrainingSessionSnapshot(
        state = state,
        repetitions = repetitions,
        targetReps = launchArgs.targetReps,
        targetReached = repetitions >= launchArgs.targetReps,
        activeDurationMs = activeDurationAt(elapsedRealtimeMs()),
    )

    private fun finish(status: TrainingResultStatus): SessionResult {
        check(state == TrainingSessionState.ACTIVE || state == TrainingSessionState.PAUSED) {
            "Only an active or paused session can finish"
        }
        val nowElapsed = elapsedRealtimeMs()
        val result = SessionResult(
            sessionId = launchArgs.sessionId,
            exercise = launchArgs.exercise,
            actualReps = repetitions,
            status = status,
            startedAtMs = checkNotNull(startedAtWallMs),
            endedAtMs = currentTimeMs(),
            durationMs = activeDurationAt(nowElapsed),
        )
        state = when (status) {
            TrainingResultStatus.COMPLETED -> TrainingSessionState.COMPLETED
            TrainingResultStatus.CANCELLED -> TrainingSessionState.CANCELLED
        }
        return result
    }

    private fun activeDurationAt(nowElapsedMs: Long): Long {
        val started = startedAtElapsedMs ?: return 0L
        val effectiveEnd = pauseStartedAtElapsedMs ?: nowElapsedMs
        return (effectiveEnd - started - totalPausedMs).coerceAtLeast(0L)
    }
}
