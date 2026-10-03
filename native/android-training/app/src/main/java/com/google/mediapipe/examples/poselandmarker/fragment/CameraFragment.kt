/*
 * Copyright 2023 The TensorFlow Authors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.google.mediapipe.examples.poselandmarker.fragment

import android.annotation.SuppressLint
import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.AdapterView
import android.widget.Toast
import androidx.camera.core.Preview
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Camera
import androidx.camera.core.AspectRatio
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import androidx.navigation.Navigation
import com.google.mediapipe.examples.poselandmarker.PoseLandmarkerHelper
import com.google.mediapipe.examples.poselandmarker.MainViewModel
import com.google.mediapipe.examples.poselandmarker.R
import com.google.mediapipe.examples.poselandmarker.TrainingActivity
import com.google.mediapipe.examples.poselandmarker.databinding.FragmentCameraBinding
import com.google.mediapipe.examples.poselandmarker.training.ExerciseAnalyzer
import com.google.mediapipe.examples.poselandmarker.training.ExerciseKind
import com.google.mediapipe.examples.poselandmarker.training.FeedbackCode
import com.google.mediapipe.examples.poselandmarker.training.Landmark2D
import com.google.mediapipe.examples.poselandmarker.training.MotionDirection
import com.google.mediapipe.examples.poselandmarker.training.MotionPhase
import com.google.mediapipe.examples.poselandmarker.training.TrainingSnapshot
import com.google.mediapipe.examples.poselandmarker.training.session.TrainingSessionSnapshot
import com.google.mediapipe.examples.poselandmarker.training.session.TrainingSessionState
import com.google.mediapipe.tasks.vision.core.RunningMode
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class CameraFragment : Fragment(), PoseLandmarkerHelper.LandmarkerListener {

    companion object {
        private const val TAG = "Pose Landmarker"
        private const val EVENT_TAG = "FitnessCoachEvent"
    }

    private var _fragmentCameraBinding: FragmentCameraBinding? = null

    private val fragmentCameraBinding
        get() = _fragmentCameraBinding!!

    private lateinit var poseLandmarkerHelper: PoseLandmarkerHelper
    private val viewModel: MainViewModel by activityViewModels()
    private var preview: Preview? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var cameraFacing = CameraSelector.LENS_FACING_BACK
    private val exerciseAnalyzer = ExerciseAnalyzer()

    private val trainingActivity: TrainingActivity
        get() = requireActivity() as TrainingActivity

    /** Blocking ML operations are performed using this executor */
    private lateinit var backgroundExecutor: ExecutorService

    override fun onResume() {
        super.onResume()
        // Make sure that all permissions are still present, since the
        // user could have removed them while the app was in paused state.
        if (!PermissionsFragment.hasPermissions(requireContext())) {
            Navigation.findNavController(
                requireActivity(), R.id.fragment_container
            ).navigate(R.id.action_camera_to_permissions)
        }

        // Start the PoseLandmarkerHelper again when users come back
        // to the foreground.
        backgroundExecutor.execute {
            if(this::poseLandmarkerHelper.isInitialized) {
                if (poseLandmarkerHelper.isClose()) {
                    poseLandmarkerHelper.setupPoseLandmarker()
                }
            }
        }
    }

    override fun onPause() {
        super.onPause()
        exerciseAnalyzer.cancelCurrentMotionCycle()
        if(this::poseLandmarkerHelper.isInitialized) {
            viewModel.setMinPoseDetectionConfidence(poseLandmarkerHelper.minPoseDetectionConfidence)
            viewModel.setMinPoseTrackingConfidence(poseLandmarkerHelper.minPoseTrackingConfidence)
            viewModel.setMinPosePresenceConfidence(poseLandmarkerHelper.minPosePresenceConfidence)
            viewModel.setDelegate(poseLandmarkerHelper.currentDelegate)

            // Close the PoseLandmarkerHelper and release resources
            backgroundExecutor.execute { poseLandmarkerHelper.clearPoseLandmarker() }
        }
    }

    override fun onDestroyView() {
        _fragmentCameraBinding = null
        super.onDestroyView()

        // Shut down our background executor
        backgroundExecutor.shutdown()
        backgroundExecutor.awaitTermination(
            Long.MAX_VALUE, TimeUnit.NANOSECONDS
        )
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _fragmentCameraBinding =
            FragmentCameraBinding.inflate(inflater, container, false)

        return fragmentCameraBinding.root
    }

    @SuppressLint("MissingPermission")
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        trainingActivity.ensureSessionStarted()

        // Initialize our background executor
        backgroundExecutor = Executors.newSingleThreadExecutor()

        // Wait for the views to be properly laid out
        fragmentCameraBinding.viewFinder.post {
            // Set up the camera and its use cases
            setUpCamera()
        }

        // Create the PoseLandmarkerHelper that will handle the inference
        backgroundExecutor.execute {
            poseLandmarkerHelper = PoseLandmarkerHelper(
                context = requireContext(),
                runningMode = RunningMode.LIVE_STREAM,
                minPoseDetectionConfidence = viewModel.currentMinPoseDetectionConfidence,
                minPoseTrackingConfidence = viewModel.currentMinPoseTrackingConfidence,
                minPosePresenceConfidence = viewModel.currentMinPosePresenceConfidence,
                currentDelegate = viewModel.currentDelegate,
                currentModel = viewModel.currentModel,
                poseLandmarkerHelperListener = this
            )
        }

        // Attach listeners to UI control widgets
        initBottomSheetControls()
        initTrainingControls()
    }

    private fun initTrainingControls() {
        fragmentCameraBinding.squatButton.setOnClickListener {
            selectExercise(ExerciseKind.SQUAT)
        }
        fragmentCameraBinding.pushUpButton.setOnClickListener {
            selectExercise(ExerciseKind.PUSH_UP)
        }
        fragmentCameraBinding.resetButton.setOnClickListener {
            exerciseAnalyzer.reset()
            trainingActivity.restartDemoSession(exerciseAnalyzer.exercise)
            resetTrainingHud()
        }
        fragmentCameraBinding.switchCameraButton.setOnClickListener {
            cameraFacing = if (cameraFacing == CameraSelector.LENS_FACING_BACK) {
                CameraSelector.LENS_FACING_FRONT
            } else {
                CameraSelector.LENS_FACING_BACK
            }
            bindCameraUseCases()
        }
        fragmentCameraBinding.pauseButton.setOnClickListener {
            exerciseAnalyzer.cancelCurrentMotionCycle()
            renderSessionSnapshot(trainingActivity.togglePause())
        }
        fragmentCameraBinding.finishButton.setOnClickListener {
            trainingActivity.completeTraining()
        }
        fragmentCameraBinding.cancelButton.setOnClickListener {
            trainingActivity.requestCancelTraining()
        }

        val initialExercise = trainingActivity.launchArgs.exercise
        exerciseAnalyzer.selectExercise(initialExercise)
        val switchingAllowed = trainingActivity.allowsExerciseSwitching
        fragmentCameraBinding.squatButton.isEnabled = switchingAllowed
        fragmentCameraBinding.pushUpButton.isEnabled = switchingAllowed
        fragmentCameraBinding.exerciseSelectorRow.visibility =
            if (switchingAllowed) View.VISIBLE else View.GONE
        fragmentCameraBinding.resetButton.visibility =
            if (switchingAllowed) View.VISIBLE else View.GONE
        updateExerciseButtons(initialExercise)
        resetTrainingHud()
    }

    private fun selectExercise(exercise: ExerciseKind) {
        exerciseAnalyzer.selectExercise(exercise)
        trainingActivity.restartDemoSession(exercise)
        updateExerciseButtons(exercise)
        resetTrainingHud()
    }

    private fun updateExerciseButtons(exercise: ExerciseKind) {
        fragmentCameraBinding.squatButton.alpha =
            if (exercise == ExerciseKind.SQUAT) 1.0f else 0.55f
        fragmentCameraBinding.pushUpButton.alpha =
            if (exercise == ExerciseKind.PUSH_UP) 1.0f else 0.55f
    }

    private fun resetTrainingHud() {
        fragmentCameraBinding.repCountValue.text = getString(R.string.rep_count_format, 0)
        fragmentCameraBinding.phaseValue.text = getString(R.string.phase_format, "准备")
        fragmentCameraBinding.angleValue.text = getString(R.string.angle_waiting)
        fragmentCameraBinding.feedbackValue.text = getString(R.string.feedback_initial)
        fragmentCameraBinding.feedbackValue.setBackgroundColor(
            ContextCompat.getColor(requireContext(), R.color.mp_color_primary_dark)
        )
        renderSessionSnapshot(trainingActivity.sessionSnapshot())
    }

    private fun initBottomSheetControls() {
        // init bottom sheet settings

        fragmentCameraBinding.bottomSheetLayout.detectionThresholdValue.text =
            String.format(
                Locale.US, "%.2f", viewModel.currentMinPoseDetectionConfidence
            )
        fragmentCameraBinding.bottomSheetLayout.trackingThresholdValue.text =
            String.format(
                Locale.US, "%.2f", viewModel.currentMinPoseTrackingConfidence
            )
        fragmentCameraBinding.bottomSheetLayout.presenceThresholdValue.text =
            String.format(
                Locale.US, "%.2f", viewModel.currentMinPosePresenceConfidence
            )

        // When clicked, lower pose detection score threshold floor
        fragmentCameraBinding.bottomSheetLayout.detectionThresholdMinus.setOnClickListener {
            if (poseLandmarkerHelper.minPoseDetectionConfidence >= 0.2) {
                poseLandmarkerHelper.minPoseDetectionConfidence -= 0.1f
                updateControlsUi()
            }
        }

        // When clicked, raise pose detection score threshold floor
        fragmentCameraBinding.bottomSheetLayout.detectionThresholdPlus.setOnClickListener {
            if (poseLandmarkerHelper.minPoseDetectionConfidence <= 0.8) {
                poseLandmarkerHelper.minPoseDetectionConfidence += 0.1f
                updateControlsUi()
            }
        }

        // When clicked, lower pose tracking score threshold floor
        fragmentCameraBinding.bottomSheetLayout.trackingThresholdMinus.setOnClickListener {
            if (poseLandmarkerHelper.minPoseTrackingConfidence >= 0.2) {
                poseLandmarkerHelper.minPoseTrackingConfidence -= 0.1f
                updateControlsUi()
            }
        }

        // When clicked, raise pose tracking score threshold floor
        fragmentCameraBinding.bottomSheetLayout.trackingThresholdPlus.setOnClickListener {
            if (poseLandmarkerHelper.minPoseTrackingConfidence <= 0.8) {
                poseLandmarkerHelper.minPoseTrackingConfidence += 0.1f
                updateControlsUi()
            }
        }

        // When clicked, lower pose presence score threshold floor
        fragmentCameraBinding.bottomSheetLayout.presenceThresholdMinus.setOnClickListener {
            if (poseLandmarkerHelper.minPosePresenceConfidence >= 0.2) {
                poseLandmarkerHelper.minPosePresenceConfidence -= 0.1f
                updateControlsUi()
            }
        }

        // When clicked, raise pose presence score threshold floor
        fragmentCameraBinding.bottomSheetLayout.presenceThresholdPlus.setOnClickListener {
            if (poseLandmarkerHelper.minPosePresenceConfidence <= 0.8) {
                poseLandmarkerHelper.minPosePresenceConfidence += 0.1f
                updateControlsUi()
            }
        }

        // When clicked, change the underlying hardware used for inference.
        // Current options are CPU and GPU
        fragmentCameraBinding.bottomSheetLayout.spinnerDelegate.setSelection(
            viewModel.currentDelegate, false
        )
        fragmentCameraBinding.bottomSheetLayout.spinnerDelegate.onItemSelectedListener =
            object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(
                    p0: AdapterView<*>?, p1: View?, p2: Int, p3: Long
                ) {
                    try {
                        poseLandmarkerHelper.currentDelegate = p2
                        updateControlsUi()
                    } catch(e: UninitializedPropertyAccessException) {
                        Log.e(TAG, "PoseLandmarkerHelper has not been initialized yet.")
                    }
                }

                override fun onNothingSelected(p0: AdapterView<*>?) {
                    /* no op */
                }
            }

        // When clicked, change the underlying model used for object detection
        fragmentCameraBinding.bottomSheetLayout.spinnerModel.setSelection(
            viewModel.currentModel,
            false
        )
        fragmentCameraBinding.bottomSheetLayout.spinnerModel.onItemSelectedListener =
            object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(
                    p0: AdapterView<*>?,
                    p1: View?,
                    p2: Int,
                    p3: Long
                ) {
                    poseLandmarkerHelper.currentModel = p2
                    updateControlsUi()
                }

                override fun onNothingSelected(p0: AdapterView<*>?) {
                    /* no op */
                }
            }
    }

    // Update the values displayed in the bottom sheet. Reset Poselandmarker
    // helper.
    private fun updateControlsUi() {
        if(this::poseLandmarkerHelper.isInitialized) {
            fragmentCameraBinding.bottomSheetLayout.detectionThresholdValue.text =
                String.format(
                    Locale.US,
                    "%.2f",
                    poseLandmarkerHelper.minPoseDetectionConfidence
                )
            fragmentCameraBinding.bottomSheetLayout.trackingThresholdValue.text =
                String.format(
                    Locale.US,
                    "%.2f",
                    poseLandmarkerHelper.minPoseTrackingConfidence
                )
            fragmentCameraBinding.bottomSheetLayout.presenceThresholdValue.text =
                String.format(
                    Locale.US,
                    "%.2f",
                    poseLandmarkerHelper.minPosePresenceConfidence
                )

            // Needs to be cleared instead of reinitialized because the GPU
            // delegate needs to be initialized on the thread using it when applicable
            backgroundExecutor.execute {
                poseLandmarkerHelper.clearPoseLandmarker()
                poseLandmarkerHelper.setupPoseLandmarker()
            }
            fragmentCameraBinding.overlay.clear()
        }
    }

    // Initialize CameraX, and prepare to bind the camera use cases
    private fun setUpCamera() {
        val cameraProviderFuture =
            ProcessCameraProvider.getInstance(requireContext())
        cameraProviderFuture.addListener(
            {
                // CameraProvider
                cameraProvider = cameraProviderFuture.get()

                // Build and bind the camera use cases
                bindCameraUseCases()
            }, ContextCompat.getMainExecutor(requireContext())
        )
    }

    // Declare and bind preview, capture and analysis use cases
    @SuppressLint("UnsafeOptInUsageError")
    private fun bindCameraUseCases() {

        // CameraProvider
        val cameraProvider = cameraProvider
            ?: throw IllegalStateException("Camera initialization failed.")

        val cameraSelector =
            CameraSelector.Builder().requireLensFacing(cameraFacing).build()

        // Preview. Only using the 4:3 ratio because this is the closest to our models
        preview = Preview.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3)
            .setTargetRotation(fragmentCameraBinding.viewFinder.display.rotation)
            .build()

        // ImageAnalysis. Using RGBA 8888 to match how our models work
        imageAnalyzer =
            ImageAnalysis.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3)
                .setTargetRotation(fragmentCameraBinding.viewFinder.display.rotation)
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .build()
                // The analyzer can then be assigned to the instance
                .also {
                    it.setAnalyzer(backgroundExecutor) { image ->
                        detectPose(image)
                    }
                }

        // Must unbind the use-cases before rebinding them
        cameraProvider.unbindAll()

        try {
            // A variable number of use-cases can be passed here -
            // camera provides access to CameraControl & CameraInfo
            camera = cameraProvider.bindToLifecycle(
                this, cameraSelector, preview, imageAnalyzer
            )

            // Attach the viewfinder's surface provider to preview use case
            preview?.setSurfaceProvider(fragmentCameraBinding.viewFinder.surfaceProvider)
        } catch (exc: Exception) {
            Log.e(TAG, "Use case binding failed", exc)
            trainingActivity.onTrainingUnavailable(
                "Camera use case binding failed: ${exc.message.orEmpty()}"
            )
        }
    }

    private fun detectPose(imageProxy: ImageProxy) {
        if(this::poseLandmarkerHelper.isInitialized) {
            poseLandmarkerHelper.detectLiveStream(
                imageProxy = imageProxy,
                isFrontCamera = cameraFacing == CameraSelector.LENS_FACING_FRONT
            )
        }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        imageAnalyzer?.targetRotation =
            fragmentCameraBinding.viewFinder.display.rotation
    }

    // Update UI after pose have been detected. Extracts original
    // image height/width to scale and place the landmarks properly through
    // OverlayView
    override fun onResults(
        resultBundle: PoseLandmarkerHelper.ResultBundle
    ) {
        val host = activity as? TrainingActivity ?: return
        val poseResult = resultBundle.results.first()
        val landmarks = poseResult.landmarks().firstOrNull()?.map {
            Landmark2D(
                x = it.x(),
                y = it.y(),
                visibility = it.visibility().orElse(1f),
                presence = it.presence().orElse(1f),
            )
        }.orEmpty()
        val trainingSnapshot = if (host.isTrainingActive()) {
            exerciseAnalyzer.process(
                landmarks = landmarks,
                timestampMs = System.currentTimeMillis(),
                frameWidth = resultBundle.inputImageWidth,
                frameHeight = resultBundle.inputImageHeight,
            ).also(host::onTrainingSnapshot)
        } else {
            null
        }
        trainingSnapshot?.event?.let { event ->
            Log.i(EVENT_TAG, event.toJson(host.launchArgs.sessionId))
        }

        activity?.runOnUiThread {
            if (_fragmentCameraBinding != null) {
                fragmentCameraBinding.bottomSheetLayout.inferenceTimeVal.text =
                    String.format("%d ms", resultBundle.inferenceTime)

                // Pass necessary information to OverlayView for drawing on the canvas
                fragmentCameraBinding.overlay.setResults(
                    poseResult,
                    resultBundle.inputImageHeight,
                    resultBundle.inputImageWidth,
                    RunningMode.LIVE_STREAM
                )

                // Force a redraw
                fragmentCameraBinding.overlay.invalidate()
                trainingSnapshot?.let(::renderTrainingSnapshot)
                renderSessionSnapshot(host.sessionSnapshot())
            }
        }
    }

    private fun renderSessionSnapshot(snapshot: TrainingSessionSnapshot) {
        val totalSeconds = snapshot.activeDurationMs / 1_000L
        val duration = String.format(
            Locale.US,
            "%02d:%02d",
            totalSeconds / 60L,
            totalSeconds % 60L,
        )
        fragmentCameraBinding.sessionProgressValue.text = getString(
            R.string.session_progress_format,
            snapshot.repetitions,
            snapshot.targetReps,
            duration,
        )
        fragmentCameraBinding.pauseButton.text = getString(
            if (snapshot.state == TrainingSessionState.PAUSED) {
                R.string.action_resume
            } else {
                R.string.action_pause
            }
        )
        if (snapshot.state == TrainingSessionState.PAUSED) {
            fragmentCameraBinding.phaseValue.text = getString(R.string.phase_paused)
            fragmentCameraBinding.feedbackValue.text = getString(R.string.feedback_paused)
            fragmentCameraBinding.feedbackValue.setBackgroundColor(
                ContextCompat.getColor(requireContext(), R.color.mp_color_primary_dark)
            )
        }
    }

    private fun renderTrainingSnapshot(snapshot: TrainingSnapshot) {
        fragmentCameraBinding.repCountValue.text =
            getString(R.string.rep_count_format, snapshot.repetitions)
        fragmentCameraBinding.phaseValue.text =
            getString(R.string.phase_format, phaseLabel(snapshot))
        fragmentCameraBinding.angleValue.text = snapshot.primaryAngleDegrees?.let { primary ->
            val secondary = snapshot.secondaryAngleDegrees?.let { "$it°" } ?: "—"
            val format = when (snapshot.exercise) {
                ExerciseKind.SQUAT -> R.string.squat_angle_format
                ExerciseKind.PUSH_UP -> R.string.push_up_angle_format
            }
            getString(format, primary, secondary)
        } ?: getString(R.string.angle_waiting)
        fragmentCameraBinding.feedbackValue.text = snapshot.feedbackCode.displayText
        val feedbackColor = if (snapshot.feedbackCode == FeedbackCode.OK) {
            R.color.mp_color_primary_dark
        } else {
            R.color.mp_color_error
        }
        fragmentCameraBinding.feedbackValue.setBackgroundColor(
            ContextCompat.getColor(requireContext(), feedbackColor)
        )
    }

    private fun phaseLabel(snapshot: TrainingSnapshot): String = when (snapshot.phase) {
        MotionPhase.READY -> "请保持起始姿势"
        MotionPhase.DOWN -> "底部"
        MotionPhase.UP -> if (snapshot.exercise == ExerciseKind.SQUAT) "站立" else "撑起"
        MotionPhase.NOT_VISIBLE -> "关键点不可用"
        MotionPhase.TRANSITION -> when (snapshot.direction) {
            MotionDirection.FLEXING ->
                if (snapshot.exercise == ExerciseKind.SQUAT) "下蹲中" else "下降中"
            MotionDirection.EXTENDING ->
                if (snapshot.exercise == ExerciseKind.SQUAT) "起身中" else "撑起中"
            else -> "动作中"
        }
    }

    override fun onError(error: String, errorCode: Int) {
        activity?.runOnUiThread {
            Toast.makeText(requireContext(), error, Toast.LENGTH_SHORT).show()
            if (errorCode == PoseLandmarkerHelper.GPU_ERROR) {
                fragmentCameraBinding.bottomSheetLayout.spinnerDelegate.setSelection(
                    PoseLandmarkerHelper.DELEGATE_CPU, false
                )
            } else {
                trainingActivity.onTrainingUnavailable(error)
            }
        }
    }
}
