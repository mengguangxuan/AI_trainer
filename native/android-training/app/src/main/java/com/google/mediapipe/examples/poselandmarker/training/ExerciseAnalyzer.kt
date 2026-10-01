package com.google.mediapipe.examples.poselandmarker.training

import kotlin.math.acos
import kotlin.math.abs
import kotlin.math.round
import kotlin.math.sqrt

/**
 * The small, deterministic motion-analysis layer used by the prototype.
 *
 * MediaPipe owns landmark detection. This class deliberately knows nothing about Android or
 * MediaPipe, so it can be unit-tested and later moved behind a Flutter platform channel.
 * Thresholds are prototype defaults, not medical or biomechanical claims.
 */
class ExerciseAnalyzer(
    initialExercise: ExerciseKind = ExerciseKind.SQUAT,
) {
    var exercise: ExerciseKind = initialExercise
        private set

    private var repetitions = 0
    private var reachedBottom = false
    private var stableCandidate: MotionPhase? = null
    private var stableCandidateFrames = 0
    private var stablePhase = MotionPhase.READY
    private var cycleArmed = false
    private var bottomReachedAtMs: Long? = null
    private var missingFrames = 0
    private var smoothedPrimaryAngle: Double? = null
    private var smoothedSecondaryAngle: Double? = null
    private var previousPrimaryAngle: Double? = null
    private var lastFeedbackCode = FeedbackCode.OK
    private var lastFormEventAtMs = Long.MIN_VALUE
    private var sequence = 0L

    @Synchronized
    fun selectExercise(value: ExerciseKind) {
        if (exercise != value) {
            exercise = value
            reset()
        }
    }

    @Synchronized
    fun reset() {
        repetitions = 0
        reachedBottom = false
        stableCandidate = null
        stableCandidateFrames = 0
        stablePhase = MotionPhase.READY
        cycleArmed = false
        bottomReachedAtMs = null
        missingFrames = 0
        smoothedPrimaryAngle = null
        smoothedSecondaryAngle = null
        previousPrimaryAngle = null
        lastFeedbackCode = FeedbackCode.OK
        lastFormEventAtMs = Long.MIN_VALUE
        sequence = 0L
    }

    @Synchronized
    fun process(
        landmarks: List<Landmark2D>,
        timestampMs: Long = System.currentTimeMillis(),
        frameWidth: Int = 1,
        frameHeight: Int = 1,
    ): TrainingSnapshot {
        val scaleX = frameWidth.coerceAtLeast(1).toDouble()
        val scaleY = frameHeight.coerceAtLeast(1).toDouble()
        val measurement = when (exercise) {
            ExerciseKind.SQUAT -> measureSquat(landmarks, scaleX, scaleY)
            ExerciseKind.PUSH_UP -> measurePushUp(landmarks, scaleX, scaleY)
        }

        if (measurement == null) {
            missingFrames += 1
            stableCandidate = null
            stableCandidateFrames = 0
            if (missingFrames >= MAX_MISSING_FRAMES) resetTrackingCycle()
            return snapshot(
                phase = MotionPhase.NOT_VISIBLE,
                direction = MotionDirection.UNKNOWN,
                primaryAngle = null,
                secondaryAngle = null,
                feedback = FeedbackCode.MOVE_INTO_FRAME,
                event = maybeFormEvent(FeedbackCode.MOVE_INTO_FRAME, timestampMs, emptyMap()),
            )
        }
        missingFrames = 0

        val previousPrimary = smoothedPrimaryAngle
        val primary = smooth(smoothedPrimaryAngle, measurement.primaryAngle).also {
            smoothedPrimaryAngle = it
        }
        val secondary = measurement.secondaryAngle?.let { value ->
            smooth(smoothedSecondaryAngle, value).also { smoothedSecondaryAngle = it }
        }
        val direction = directionFor(previousPrimary, primary)
        previousPrimaryAngle = primary

        val candidate = phaseFor(primary)
        val repCompleted = updateStablePhase(candidate, timestampMs)
        val feedback = feedbackFor(primary, secondary, candidate, direction)
        val metrics = linkedMapOf<String, Number>(
            primaryMetricName() to primary.roundForWire(),
        ).apply {
            if (secondary != null) put(secondaryMetricName(), secondary.roundForWire())
        }

        val event = if (repCompleted) {
            TrainingEvent(
                sequence = ++sequence,
                type = "motion.rep_completed",
                exercise = exercise.wireValue,
                timestampMs = timestampMs,
                repIndex = repetitions,
                phase = stablePhase.wireValue,
                metrics = metrics,
                feedbackCode = feedback.wireValue,
                errorCode = null,
                eventAction = null,
            )
        } else {
            maybeFormEvent(feedback, timestampMs, metrics)
        }

        return snapshot(
            phase = if (candidate == MotionPhase.TRANSITION) candidate else stablePhase,
            direction = direction,
            primaryAngle = primary,
            secondaryAngle = secondary,
            feedback = feedback,
            event = event,
        )
    }

    private fun measureSquat(
        landmarks: List<Landmark2D>,
        scaleX: Double,
        scaleY: Double,
    ): Measurement? {
        val side = bestSide(
            landmarks,
            left = intArrayOf(11, 23, 25, 27),
            right = intArrayOf(12, 24, 26, 28),
        ) ?: return null
        val (shoulder, hip, knee, ankle) = side
        return Measurement(
            primaryAngle = angle(
                landmarks[hip], landmarks[knee], landmarks[ankle], scaleX, scaleY
            ) ?: return null,
            secondaryAngle = inclinationFromVertical(
                landmarks[shoulder], landmarks[hip], scaleX, scaleY
            ),
        )
    }

    private fun measurePushUp(
        landmarks: List<Landmark2D>,
        scaleX: Double,
        scaleY: Double,
    ): Measurement? {
        val side = bestSide(
            landmarks,
            left = intArrayOf(11, 13, 15, 23, 27),
            right = intArrayOf(12, 14, 16, 24, 28),
        ) ?: return null
        val (shoulder, elbow, wrist, hip, ankle) = side
        return Measurement(
            primaryAngle = angle(
                landmarks[shoulder], landmarks[elbow], landmarks[wrist], scaleX, scaleY
            ) ?: return null,
            secondaryAngle = angle(
                landmarks[shoulder], landmarks[hip], landmarks[ankle], scaleX, scaleY
            ),
        )
    }

    private fun phaseFor(primaryAngle: Double): MotionPhase = when (exercise) {
        ExerciseKind.SQUAT -> when {
            primaryAngle <= SQUAT_BOTTOM_ANGLE -> MotionPhase.DOWN
            primaryAngle >= SQUAT_TOP_ANGLE -> MotionPhase.UP
            else -> MotionPhase.TRANSITION
        }
        ExerciseKind.PUSH_UP -> when {
            primaryAngle <= PUSH_UP_BOTTOM_ANGLE -> MotionPhase.DOWN
            primaryAngle >= PUSH_UP_TOP_ANGLE -> MotionPhase.UP
            else -> MotionPhase.TRANSITION
        }
    }

    private fun updateStablePhase(candidate: MotionPhase, timestampMs: Long): Boolean {
        if (candidate == MotionPhase.TRANSITION) {
            stableCandidate = null
            stableCandidateFrames = 0
            return false
        }

        if (stableCandidate == candidate) {
            stableCandidateFrames += 1
        } else {
            stableCandidate = candidate
            stableCandidateFrames = 1
        }

        if (stableCandidateFrames < REQUIRED_STABLE_FRAMES || stablePhase == candidate) {
            return false
        }

        stablePhase = candidate
        return when (candidate) {
            MotionPhase.DOWN -> {
                if (cycleArmed) {
                    reachedBottom = true
                    bottomReachedAtMs = timestampMs
                }
                false
            }
            MotionPhase.UP -> {
                val bottomDuration = bottomReachedAtMs?.let { timestampMs - it } ?: 0L
                val validRep = cycleArmed && reachedBottom && bottomDuration >= MIN_BOTTOM_TO_TOP_MS
                reachedBottom = false
                bottomReachedAtMs = null
                cycleArmed = true
                if (validRep) {
                    repetitions += 1
                    true
                } else {
                    false
                }
            }
            else -> false
        }
    }

    private fun feedbackFor(
        primaryAngle: Double,
        secondaryAngle: Double?,
        candidate: MotionPhase,
        direction: MotionDirection,
    ): FeedbackCode = when (exercise) {
        ExerciseKind.SQUAT -> when {
            secondaryAngle != null && secondaryAngle > SQUAT_MAX_TORSO_LEAN_ANGLE ->
                FeedbackCode.KEEP_CHEST_UP
            candidate == MotionPhase.TRANSITION &&
                direction == MotionDirection.EXTENDING &&
                primaryAngle < 135.0 && !reachedBottom && cycleArmed ->
                FeedbackCode.GO_DEEPER
            else -> FeedbackCode.OK
        }
        ExerciseKind.PUSH_UP -> when {
            secondaryAngle != null && secondaryAngle < PUSH_UP_MIN_BODY_LINE_ANGLE ->
                FeedbackCode.KEEP_BODY_STRAIGHT
            candidate == MotionPhase.TRANSITION &&
                direction == MotionDirection.EXTENDING &&
                primaryAngle < 125.0 && !reachedBottom && cycleArmed ->
                FeedbackCode.GO_LOWER
            else -> FeedbackCode.OK
        }
    }

    private fun maybeFormEvent(
        feedback: FeedbackCode,
        timestampMs: Long,
        metrics: Map<String, Number>,
    ): TrainingEvent? {
        val previousFeedback = lastFeedbackCode
        val changed = feedback != previousFeedback
        lastFeedbackCode = feedback

        if (feedback == FeedbackCode.OK && previousFeedback != FeedbackCode.OK) {
            return TrainingEvent(
                sequence = ++sequence,
                type = "motion.form_event",
                exercise = exercise.wireValue,
                timestampMs = timestampMs,
                repIndex = if (repetitions == 0) null else repetitions,
                phase = stablePhase.wireValue,
                metrics = metrics,
                feedbackCode = previousFeedback.wireValue,
                errorCode = errorCodeFor(previousFeedback),
                eventAction = "end",
            )
        }
        if (feedback == FeedbackCode.OK || !changed) return null
        if (lastFormEventAtMs != Long.MIN_VALUE && timestampMs - lastFormEventAtMs < FORM_EVENT_COOLDOWN_MS) {
            return null
        }
        lastFormEventAtMs = timestampMs
        return TrainingEvent(
            sequence = ++sequence,
            type = "motion.form_event",
            exercise = exercise.wireValue,
            timestampMs = timestampMs,
            repIndex = if (repetitions == 0) null else repetitions,
            phase = stablePhase.wireValue,
            metrics = metrics,
            feedbackCode = feedback.wireValue,
            errorCode = errorCodeFor(feedback),
            eventAction = "start",
        )
    }

    private fun errorCodeFor(feedback: FeedbackCode): String? = when (feedback) {
        FeedbackCode.OK -> null
        FeedbackCode.MOVE_INTO_FRAME -> "camera.landmarks_missing"
        FeedbackCode.GO_DEEPER -> "squat.depth_shallow"
        FeedbackCode.KEEP_CHEST_UP -> "squat.torso_lean"
        FeedbackCode.GO_LOWER -> "push_up.depth_shallow"
        FeedbackCode.KEEP_BODY_STRAIGHT -> "push_up.body_line_bent"
    }

    private fun snapshot(
        phase: MotionPhase,
        direction: MotionDirection,
        primaryAngle: Double?,
        secondaryAngle: Double?,
        feedback: FeedbackCode,
        event: TrainingEvent?,
    ) = TrainingSnapshot(
        exercise = exercise,
        repetitions = repetitions,
        phase = phase,
        direction = direction,
        primaryAngleDegrees = primaryAngle?.toInt(),
        secondaryAngleDegrees = secondaryAngle?.toInt(),
        feedbackCode = feedback,
        event = event,
    )

    private fun primaryMetricName() = when (exercise) {
        ExerciseKind.SQUAT -> "knee_angle_deg"
        ExerciseKind.PUSH_UP -> "elbow_angle_deg"
    }

    private fun secondaryMetricName() = when (exercise) {
        ExerciseKind.SQUAT -> "torso_lean_deg"
        ExerciseKind.PUSH_UP -> "body_line_angle_deg"
    }

    private fun bestSide(
        landmarks: List<Landmark2D>,
        left: IntArray,
        right: IntArray,
    ): IntArray? {
        val leftConfidence = sideConfidence(landmarks, left)
        val rightConfidence = sideConfidence(landmarks, right)
        return when {
            leftConfidence == null && rightConfidence == null -> null
            (leftConfidence ?: -1f) >= (rightConfidence ?: -1f) -> left
            else -> right
        }
    }

    private fun sideConfidence(landmarks: List<Landmark2D>, indices: IntArray): Float? {
        if (indices.any { it !in landmarks.indices }) return null
        val points = indices.map { landmarks[it] }
        if (points.any { !it.isReliable(MIN_LANDMARK_CONFIDENCE) }) return null
        return points.minOf { it.confidence }
    }

    private fun angle(
        a: Landmark2D,
        b: Landmark2D,
        c: Landmark2D,
        scaleX: Double,
        scaleY: Double,
    ): Double? {
        val bax = (a.x - b.x) * scaleX
        val bay = (a.y - b.y) * scaleY
        val bcx = (c.x - b.x) * scaleX
        val bcy = (c.y - b.y) * scaleY
        val baLength = sqrt(bax * bax + bay * bay)
        val bcLength = sqrt(bcx * bcx + bcy * bcy)
        if (baLength < MIN_SEGMENT_LENGTH || bcLength < MIN_SEGMENT_LENGTH) return null
        val cosine = ((bax * bcx + bay * bcy) / (baLength * bcLength)).coerceIn(-1.0, 1.0)
        return Math.toDegrees(acos(cosine))
    }

    private fun inclinationFromVertical(
        shoulder: Landmark2D,
        hip: Landmark2D,
        scaleX: Double,
        scaleY: Double,
    ): Double? {
        val dx = (shoulder.x - hip.x) * scaleX
        val dy = (shoulder.y - hip.y) * scaleY
        val length = sqrt(dx * dx + dy * dy)
        if (length < MIN_SEGMENT_LENGTH) return null
        val cosine = (-dy / length).coerceIn(-1.0, 1.0)
        return Math.toDegrees(acos(cosine))
    }

    private fun directionFor(previous: Double?, current: Double): MotionDirection {
        if (previous == null) return MotionDirection.STABLE
        val delta = current - previous
        return when {
            abs(delta) < MIN_DIRECTION_DELTA -> MotionDirection.STABLE
            delta < 0.0 -> MotionDirection.FLEXING
            else -> MotionDirection.EXTENDING
        }
    }

    private fun resetTrackingCycle() {
        reachedBottom = false
        stableCandidate = null
        stableCandidateFrames = 0
        stablePhase = MotionPhase.READY
        cycleArmed = false
        bottomReachedAtMs = null
        smoothedPrimaryAngle = null
        smoothedSecondaryAngle = null
        previousPrimaryAngle = null
    }

    private fun smooth(previous: Double?, current: Double): Double =
        previous?.let { it + SMOOTHING_ALPHA * (current - it) } ?: current

    private data class Measurement(
        val primaryAngle: Double,
        val secondaryAngle: Double?,
    )

    companion object {
        private const val SQUAT_BOTTOM_ANGLE = 105.0
        private const val SQUAT_TOP_ANGLE = 155.0
        private const val SQUAT_MAX_TORSO_LEAN_ANGLE = 45.0
        private const val PUSH_UP_BOTTOM_ANGLE = 95.0
        private const val PUSH_UP_TOP_ANGLE = 150.0
        private const val PUSH_UP_MIN_BODY_LINE_ANGLE = 155.0
        private const val REQUIRED_STABLE_FRAMES = 5
        private const val MAX_MISSING_FRAMES = 5
        private const val MIN_BOTTOM_TO_TOP_MS = 250L
        private const val FORM_EVENT_COOLDOWN_MS = 1_500L
        private const val MIN_SEGMENT_LENGTH = 0.015
        private const val MIN_LANDMARK_CONFIDENCE = 0.55f
        private const val MIN_DIRECTION_DELTA = 1.0
        private const val SMOOTHING_ALPHA = 0.45
    }
}

data class Landmark2D(
    val x: Float,
    val y: Float,
    val visibility: Float = 1f,
    val presence: Float = 1f,
) {
    val confidence: Float get() = minOf(visibility, presence)
    fun isFinite(): Boolean = x.isFinite() && y.isFinite()
    fun isReliable(minConfidence: Float): Boolean =
        isFinite() && visibility.isFinite() && presence.isFinite() && confidence >= minConfidence
}

enum class ExerciseKind(val wireValue: String, val displayName: String) {
    SQUAT("squat", "深蹲"),
    PUSH_UP("push_up", "俯卧撑"),
}

enum class MotionPhase(val wireValue: String, val displayName: String) {
    READY("ready", "准备"),
    DOWN("down", "最低点"),
    UP("up", "起始位"),
    TRANSITION("transition", "运动中"),
    NOT_VISIBLE("not_visible", "未检测到全身"),
}

enum class MotionDirection {
    UNKNOWN,
    STABLE,
    FLEXING,
    EXTENDING,
}

enum class FeedbackCode(val wireValue: String, val displayText: String) {
    OK("OK", "姿态已识别，保持节奏"),
    MOVE_INTO_FRAME("ADJUST_CAMERA_POSITION", "请退后一些，确保关键关节进入画面"),
    GO_DEEPER("GO_DEEPER", "再下蹲一点，达到有效幅度"),
    KEEP_CHEST_UP("KEEP_CHEST_UP", "胸部抬起，避免躯干过度前倾"),
    GO_LOWER("GO_LOWER", "再下降一点，完成有效幅度"),
    KEEP_BODY_STRAIGHT("KEEP_BODY_STRAIGHT", "收紧核心，让肩、髋、踝保持一条线"),
}

data class TrainingSnapshot(
    val exercise: ExerciseKind,
    val repetitions: Int,
    val phase: MotionPhase,
    val direction: MotionDirection,
    val primaryAngleDegrees: Int?,
    val secondaryAngleDegrees: Int?,
    val feedbackCode: FeedbackCode,
    val event: TrainingEvent?,
)

data class TrainingEvent(
    val sequence: Long,
    val type: String,
    val exercise: String,
    val timestampMs: Long,
    val repIndex: Int?,
    val phase: String,
    val metrics: Map<String, Number>,
    val feedbackCode: String?,
    val errorCode: String?,
    val eventAction: String?,
) {
    /** A prototype envelope aligned with the event-centric part of protocol v0.1. */
    fun toJson(sessionId: String = "local-prototype"): String {
        val metricJson = metrics.entries.joinToString(",") { (key, value) ->
            "\"${key.jsonEscape()}\":$value"
        }
        val repJson = repIndex?.toString() ?: "null"
        val feedbackJson = feedbackCode?.let { "\"${it.jsonEscape()}\"" } ?: "null"
        val errorJson = errorCode?.let { "\"${it.jsonEscape()}\"" } ?: "null"
        val actionJson = eventAction?.let { "\"${it.jsonEscape()}\"" } ?: "null"
        return "{" +
            "\"protocol_version\":\"0.1\"," +
            "\"message_id\":\"local_${timestampMs}_$sequence\"," +
            "\"type\":\"${type.jsonEscape()}\"," +
            "\"session_id\":\"${sessionId.jsonEscape()}\"," +
            "\"sequence\":$sequence," +
            "\"client_time_ms\":$timestampMs," +
            "\"requires_ack\":false," +
            "\"payload\":{" +
                "\"exercise_id\":\"${exercise.jsonEscape()}\"," +
                "\"rep_index\":$repJson," +
                "\"phase\":\"${phase.jsonEscape()}\"," +
                "\"event_action\":$actionJson," +
                "\"error_code\":$errorJson," +
                "\"metrics\":{$metricJson}," +
                "\"feedback_code\":$feedbackJson" +
            "}" +
            "}"
    }
}

private fun Double.roundForWire(): Double = round(this * 10.0) / 10.0

private fun String.jsonEscape(): String =
    replace("\\", "\\\\").replace("\"", "\\\"")
