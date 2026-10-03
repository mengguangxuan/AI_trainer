package com.google.mediapipe.examples.poselandmarker.training

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.cos
import kotlin.math.sin

class ExerciseAnalyzerTest {
    @Test
    fun squatCountsOnlyAfterBottomThenTop() {
        val analyzer = ExerciseAnalyzer(ExerciseKind.SQUAT)

        repeat(8) { analyzer.process(squatPose(170.0), it * 33L) }
        repeat(12) { index -> analyzer.process(squatPose(88.0), 300L + index * 33L) }
        var result = analyzer.process(squatPose(170.0), 750L)
        repeat(15) { index -> result = analyzer.process(squatPose(170.0), 783L + index * 33L) }

        assertEquals(1, result.repetitions)
        assertEquals(MotionPhase.UP, result.phase)
        assertTrue(result.event == null || result.event?.type == "motion.rep_completed")
    }

    @Test
    fun stayingAtTopDoesNotCreateFalseRepetitions() {
        val analyzer = ExerciseAnalyzer(ExerciseKind.SQUAT)
        var result = analyzer.process(squatPose(170.0), 0L)

        repeat(20) { index -> result = analyzer.process(squatPose(170.0), index * 33L) }

        assertEquals(0, result.repetitions)
    }

    @Test
    fun startingAtBottomDoesNotCreateARepetition() {
        val analyzer = ExerciseAnalyzer(ExerciseKind.SQUAT)

        repeat(12) { analyzer.process(squatPose(88.0), it * 33L) }
        var result = analyzer.process(squatPose(170.0), 450L)
        repeat(15) { index -> result = analyzer.process(squatPose(170.0), 483L + index * 33L) }

        assertEquals(0, result.repetitions)
    }

    @Test
    fun losingLandmarksAtBottomInvalidatesTheCurrentCycle() {
        val analyzer = ExerciseAnalyzer(ExerciseKind.SQUAT)

        repeat(8) { analyzer.process(squatPose(170.0), it * 33L) }
        repeat(12) { index -> analyzer.process(squatPose(88.0), 300L + index * 33L) }
        repeat(5) { index -> analyzer.process(emptyList(), 750L + index * 33L) }
        var result = analyzer.process(squatPose(170.0), 950L)
        repeat(15) { index -> result = analyzer.process(squatPose(170.0), 983L + index * 33L) }

        assertEquals(0, result.repetitions)
    }

    @Test
    fun unreliableSideIsIgnoredWhenOtherSideIsVisible() {
        val analyzer = ExerciseAnalyzer(ExerciseKind.SQUAT)
        val pose = squatPose(170.0).toMutableList()
        intArrayOf(11, 23, 25, 27).forEach { index ->
            pose[index] = pose[index].copy(visibility = 0.1f)
        }

        val result = analyzer.process(pose, 0L)

        assertTrue(result.primaryAngleDegrees != null)
        assertTrue(result.phase != MotionPhase.NOT_VISIBLE)
    }

    @Test
    fun squatTorsoMetricIsInclinationFromVertical() {
        val analyzer = ExerciseAnalyzer(ExerciseKind.SQUAT)
        val pose = squatPose(170.0).toMutableList()
        pose[11] = Landmark2D(0.42f, 0.18f)
        pose[23] = Landmark2D(0.42f, 0.30f)
        pose[12] = Landmark2D(0.58f, 0.18f)
        pose[24] = Landmark2D(0.58f, 0.30f)

        val result = analyzer.process(pose, 0L)

        assertEquals(0, result.secondaryAngleDegrees)
        assertTrue(result.feedbackCode != FeedbackCode.KEEP_CHEST_UP)
    }

    @Test
    fun pushUpReportsBentBodyLine() {
        val analyzer = ExerciseAnalyzer(ExerciseKind.PUSH_UP)
        val result = analyzer.process(pushUpPose(elbowAngle = 120.0, bodyLineAngle = 125.0), 2_000L)

        assertEquals(FeedbackCode.KEEP_BODY_STRAIGHT, result.feedbackCode)
        assertNotNull(result.event)
        assertEquals("motion.form_event", result.event?.type)
        assertTrue(result.event?.toJson()?.contains("push_up.body_line_bent") == true)
    }

    @Test
    fun missingLandmarksRequestsReframing() {
        val analyzer = ExerciseAnalyzer()
        val result = analyzer.process(emptyList(), 0L)

        assertEquals(MotionPhase.NOT_VISIBLE, result.phase)
        assertEquals(FeedbackCode.MOVE_INTO_FRAME, result.feedbackCode)
    }

    @Test
    fun suppressedErrorStartDoesNotProduceOrphanEndEvents() {
        val analyzer = ExerciseAnalyzer()

        val firstStart = analyzer.process(emptyList(), 0L).event
        val firstEnd = analyzer.process(squatPose(170.0), 100L).event
        val suppressedStart = analyzer.process(emptyList(), 200L).event
        val orphanEnd = analyzer.process(squatPose(170.0), 300L).event

        assertEquals("start", firstStart?.eventAction)
        assertEquals("end", firstEnd?.eventAction)
        assertEquals(null, suppressedStart)
        assertEquals(null, orphanEnd)
    }

    private fun squatPose(kneeAngle: Double): List<Landmark2D> {
        val points = blankPose()
        setJointAngle(points, 23, 25, 27, kneeAngle, 0.42f)
        setJointAngle(points, 24, 26, 28, kneeAngle, 0.58f)
        points[11] = Landmark2D(0.42f, 0.18f)
        points[12] = Landmark2D(0.58f, 0.18f)
        return points
    }

    private fun pushUpPose(elbowAngle: Double, bodyLineAngle: Double): List<Landmark2D> {
        val points = blankPose()
        setJointAngle(points, 11, 13, 15, elbowAngle, 0.38f)
        setJointAngle(points, 12, 14, 16, elbowAngle, 0.62f)
        setJointAngle(points, 11, 23, 27, bodyLineAngle, 0.40f)
        setJointAngle(points, 12, 24, 28, bodyLineAngle, 0.60f)
        return points
    }

    private fun blankPose() = MutableList(33) { Landmark2D(0.5f, 0.5f) }

    private fun setJointAngle(
        points: MutableList<Landmark2D>,
        first: Int,
        joint: Int,
        third: Int,
        angleDegrees: Double,
        x: Float,
    ) {
        val radius = 0.16
        val radians = Math.toRadians(angleDegrees)
        points[first] = Landmark2D(x, 0.30f)
        points[joint] = Landmark2D(x, 0.46f)
        points[third] = Landmark2D(
            (x + radius * sin(radians)).toFloat(),
            (0.46 - radius * cos(radians)).toFloat(),
        )
    }
}
