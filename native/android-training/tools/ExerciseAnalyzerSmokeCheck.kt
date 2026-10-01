import com.google.mediapipe.examples.poselandmarker.training.ExerciseAnalyzer
import com.google.mediapipe.examples.poselandmarker.training.ExerciseKind
import com.google.mediapipe.examples.poselandmarker.training.FeedbackCode
import com.google.mediapipe.examples.poselandmarker.training.Landmark2D
import kotlin.math.cos
import kotlin.math.sin

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

private fun squatPose(angle: Double): List<Landmark2D> {
    val points = blankPose()
    setJointAngle(points, 23, 25, 27, angle, 0.42f)
    setJointAngle(points, 24, 26, 28, angle, 0.58f)
    points[11] = Landmark2D(0.42f, 0.18f)
    points[12] = Landmark2D(0.58f, 0.18f)
    return points
}

fun main() {
    val analyzer = ExerciseAnalyzer(ExerciseKind.SQUAT)
    repeat(8) { analyzer.process(squatPose(170.0), it * 33L) }
    repeat(12) { index -> analyzer.process(squatPose(88.0), 300L + index * 33L) }
    var result = analyzer.process(squatPose(170.0), 750L)
    repeat(15) { index -> result = analyzer.process(squatPose(170.0), 783L + index * 33L) }
    check(result.repetitions == 1) { "Expected one squat, got ${result.repetitions}" }

    analyzer.reset()
    repeat(20) { index -> result = analyzer.process(squatPose(170.0), 1_000L + index * 33L) }
    check(result.repetitions == 0) { "Standing still must not count a repetition" }

    val missing = analyzer.process(emptyList(), 2_000L)
    check(missing.feedbackCode == FeedbackCode.MOVE_INTO_FRAME)
    println("ExerciseAnalyzer smoke checks passed")
}
