package com.codecritters.crittersleuthcamera

// Imports for spinner

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.util.Log
import android.widget.ArrayAdapter
import android.widget.Spinner
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.codecritters.crittersleuthcamera.databinding.ActivityMainBinding
import kotlinx.coroutines.launch
import okhttp3.MultipartBody
import retrofit2.Call
import retrofit2.Retrofit
import retrofit2.awaitResponse
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Part
import java.io.File
import java.net.URI
import java.nio.ByteBuffer
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors


typealias LumaListener = (luma: Double) -> Unit

class MainActivity : AppCompatActivity(){

    private final val API_URL = "https://crittersleuthbackend.keshuac.com/api/v1"
    private lateinit var viewBinding: ActivityMainBinding

    private var imageCapture: ImageCapture? = null

    private var videoCapture: VideoCapture<Recorder>? = null
    private var recording: Recording? = null

    private var spinnerModels: Spinner? = null

    private lateinit var cameraExecutor: ExecutorService

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        viewBinding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(viewBinding.root)

        // Request camera permissions
        if (allPermissionsGranted()) {
            startCamera()

        } else {
            requestPermissions()
        }

        // Set up the listeners for take photo and video capture buttons
        viewBinding.imageCaptureButton.setOnClickListener { takePhoto() }
        viewBinding.choosephotobutton.setOnClickListener { onChooseImageButtonClick() }
//        viewBinding.videoCaptureButton.setOnClickListener { captureVideo() }

        cameraExecutor = Executors.newSingleThreadExecutor()
        retrofit = Retrofit.Builder()
            .baseUrl("https://crittersleuthbackend.keshuac.com/")
            .addConverterFactory(GsonConverterFactory.create())
            .build()
//        val userApi = retrofit.create(ImageApi::class.java)
//        var testModels = arrayOf<String>()
//        val call = userApi.getAvailableModels()
//        call.enqueue(object : Callback<List<String>> {
//            override fun onResponse(call: Call<List<String>>, response: Response <List<String>>) {
//                if (response.isSuccessful) {
//                    val raw = response.raw()
//                    val users = response.body()
//                    Log.d(TAG, "API WORKED")
//                    Log.d(TAG, "API WORKED" + users)
//                    Log.d(TAG, "API WORKED" + raw)
//                    testModels = users!!.toTypedArray()
//                    // do something with the users list
//
//                } else {
//                    // handle error response
//                    val error = response.errorBody()!!.string()
//                    Log.d(TAG, "THIS RAN")
//                    Log.d(TAG, "THIS RAN " + error)
//                }
//            }
//            override fun onFailure(call: Call<List<String>>, t: Throwable) {
//                // handle failure
//                Log.d(TAG, "THIS FAILED")
//                Log.d(TAG, "THIS FAILED" + t.message)
//                Log.d(TAG, "THIS FAILED" + t)
//
//            }
//            })
        lifecycleScope.launch {
            val testTest = arrayOf<String>("Test1", "test2", "test3")
            val testModels =  makeModelRequest()

            Log.d(TAG, "CONTENTS: " + testModels!!.joinToString(separator=","))
            Log.d(TAG, "CONTENTS: " + testTest!!.joinToString(separator=","))
        }

        
    }
    // DropDown List
    suspend fun makeModelRequest(): Array<String>?{
        val userApi = retrofit.create(ImageApi::class.java)
        val call = userApi.getAvailableModels()

        val response = call.awaitResponse()
        try {
            if (response.isSuccessful) {
                val raw = response.raw()
                val users = response.body()
                Log.d(TAG, "API WORKED")
                Log.d(TAG, "API WORKED" + users)
                Log.d(TAG, "API WORKED" + raw)
                var testModels = users!!.toTypedArray()
                // do something with the users list

                val modelSpinner: Spinner? = viewBinding.spinnerModels
//                    findViewById(R.id.spinner_models)
                if (modelSpinner != null){
                    val adapter: ArrayAdapter<String> = ArrayAdapter<String>(
                        this,
                        android.R.layout.simple_spinner_item, testModels
                    )
                    modelSpinner.adapter = adapter

                }
                return testModels

            } else {
                // handle error response
                val error = response.errorBody()!!.string()
                Log.d(TAG, "THIS RAN")
                Log.d(TAG, "THIS RAN " + error)
            }
        } catch (t: Throwable){
            Log.d(TAG, "THIS FAILED")
            Log.d(TAG, "THIS FAILED" + t.message)
            Log.d(TAG, "THIS FAILED" + t)
        }
        return null
    }
//    suspend fun makeImagePrediction(uri:String): Array<String>?{
//        val mediaType: String = "image/png"
//        val fileName: String = "photo_" + System.currentTimeMillis() + ".png"
//        val file: File = File(uri)
//
//
//        val reqFile = file.asRequestBody(mediaType.toMediaTypeOrNull())
//        var files = MultipartBody.Part.createFormData("files", fileName, reqFile)
//
//
//        val userApi = retrofit.create(ImageApi::class.java)
//        val call = userApi.getPrediction(
//
//        )
//
//        val response = call.awaitResponse()
//        try {
//            if (response.isSuccessful) {
//                val raw = response.raw()
//                val users = response.body()
//                Log.d(TAG, "API WORKED")
//                Log.d(TAG, "API WORKED" + users)
//                Log.d(TAG, "API WORKED" + raw)
//                var testModels = users!!.toTypedArray()
//                // do something with the users list
//
//                val modelSpinner: Spinner? = findViewById(R.id.spinner_models)
//                if (modelSpinner != null){
//                    val adapter: ArrayAdapter<String> = ArrayAdapter<String>(
//                        this,
//                        android.R.layout.simple_spinner_item, testModels
//                    )
//                    modelSpinner.adapter = adapter
//
//                }
//                return testModels
//
//            } else {
//                // handle error response
//                val error = response.errorBody()!!.string()
//                Log.d(TAG, "THIS RAN")
//                Log.d(TAG, "THIS RAN " + error)
//            }
//        } catch (t: Throwable){
//            Log.d(TAG, "THIS FAILED")
//            Log.d(TAG, "THIS FAILED" + t.message)
//            Log.d(TAG, "THIS FAILED" + t)
//        }
//        return null
//    }

    class prediction(val name:String, val pred: List<pred>)
    class pred(val prob:String, val insect:String)

    public interface ImageApi {
        @GET("api/v1/available_models")
        fun getAvailableModels(
        ):Call<List<String>>

        @POST("api/v1/upload_json")
        fun getPrediction(
            @Part files: MultipartBody.Part?
        ):Call<List<prediction>>

    }

    private fun takePhoto() {
        // Get a stable reference of the modifiable image capture use case
        val imageCapture = imageCapture ?: return
        // Create time stamped name and MediaStore entry.
        val name = SimpleDateFormat(FILENAME_FORMAT, Locale.US)
            .format(System.currentTimeMillis())
        val contentValues = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/jpeg")
            if(Build.VERSION.SDK_INT > Build.VERSION_CODES.P) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/CameraX-Image")
            }
        }

        // Create output options object which contains file + metadata
        val outputOptions = ImageCapture.OutputFileOptions
            .Builder(contentResolver,
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                contentValues)
            .build()

        // Set up image capture listener, which is triggered after photo has
        // been taken
        imageCapture.takePicture(
            outputOptions,
            ContextCompat.getMainExecutor(this),
            object : ImageCapture.OnImageSavedCallback {
                override fun onError(exc: ImageCaptureException) {
                    Log.e(TAG, "Photo capture failed: ${exc.message}", exc)
                }

                override fun
                        onImageSaved(output: ImageCapture.OutputFileResults){
                    val msg = "Photo capture succeeded: ${output.savedUri}"
                    Toast.makeText(baseContext, msg, Toast.LENGTH_SHORT).show()
                    Log.d(TAG, msg)

                }
            }
        )

    }

    fun onChooseImageButtonClick() {

        // Create a new intent and set its type to image
        val pickIntent = Intent()
        pickIntent.type = "image/*"
        pickIntent.action = Intent.ACTION_GET_CONTENT

        // Intent for camera activity to capture a new picture
        val takePhotoIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)

        // Title of the popup
        val pickTitle = "Choose a Picture"
        val chooserIntent = Intent.createChooser(pickIntent, pickTitle)
        chooserIntent.putExtra(
            Intent.EXTRA_INITIAL_INTENTS, arrayOf(takePhotoIntent)
        )
        resultLauncher.launch(chooserIntent)

    }
    var resultLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {

            // There are no request codes
            val selectedImage: Intent? = result.data
            val selectedImageURI: Uri? = selectedImage!!.data
            Log.d(TAG, "THIS ran" + selectedImageURI)
            Log.d(TAG,"This ran")

            val mediaType: String = "image/png"
            val fileName: String = "photo_" + System.currentTimeMillis() + ".png"

            var file = File(selectedImageURI!!.path)


//            val reqFile = file.asRequestBody(mediaType.toMediaTypeOrNull())
//            var files = MultipartBody.Part.createFormData("files", fileName, reqFile)
//
//
//            val userApi = retrofit.create(ImageApi::class.java)
//            val call = userApi.getPrediction(
//
//            )
//
//            val response = call.awaitResponse()
//            try {
//                if (response.isSuccessful) {
//                    val raw = response.raw()
//                    val users = response.body()
//                    Log.d(TAG, "API WORKED")
//                    Log.d(TAG, "API WORKED" + users)
//                    Log.d(TAG, "API WORKED" + raw)
//                    var testModels = users!!.toTypedArray()
//                    // do something with the users list
//
//                    val modelSpinner: Spinner? = findViewById(R.id.spinner_models)
//                    if (modelSpinner != null){
//                        val adapter: ArrayAdapter<String> = ArrayAdapter<String>(
//                            this,
//                            android.R.layout.simple_spinner_item, testModels
//                        )
//                        modelSpinner.adapter = adapter
//
//                    }
//                    return testModels
//
//                } else {
//                    // handle error response
//                    val error = response.errorBody()!!.string()
//                    Log.d(TAG, "THIS RAN")
//                    Log.d(TAG, "THIS RAN " + error)
//                }
//            } catch (t: Throwable){
//                Log.d(TAG, "THIS FAILED")
//                Log.d(TAG, "THIS FAILED" + t.message)
//                Log.d(TAG, "THIS FAILED" + t)
//            }
//            return null

//            (findViewById<View>(R.id.profilePicImageView) as ImageView).setImageURI(
//                selectedImage
//            )


        }
    }

    private fun captureVideo() {}

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)

        cameraProviderFuture.addListener({
            // Used to bind the lifecycle of cameras to the lifecycle owner
            val cameraProvider: ProcessCameraProvider = cameraProviderFuture.get()

            // Preview
            val preview = Preview.Builder()
                .build()
                .also {
                    it.setSurfaceProvider(viewBinding.viewFinder.surfaceProvider)
                }
            imageCapture = ImageCapture.Builder().build()

            val imageAnalyzer = ImageAnalysis.Builder()
                .build()
                .also {
                    it.setAnalyzer(cameraExecutor, LuminosityAnalyzer { luma ->
//                        Log.d(TAG, "Average luminosity: $luma")
                    })
                }


            // Select back camera as a default
            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

            try {
                // Unbind use cases before rebinding
                cameraProvider.unbindAll()

                // Bind use cases to camera
                cameraProvider.bindToLifecycle(
                    this, cameraSelector, preview, imageCapture, imageAnalyzer)


            } catch(exc: Exception) {
                Log.e(TAG, "Use case binding failed", exc)
            }

        }, ContextCompat.getMainExecutor(this))
    }

    private fun requestPermissions() {
        activityResultLauncher.launch(REQUIRED_PERMISSIONS)
    }

    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(
            baseContext, it) == PackageManager.PERMISSION_GRANTED
    }
    private val activityResultLauncher =
        registerForActivityResult(
            ActivityResultContracts.RequestMultiplePermissions())
        { permissions ->
            // Handle Permission granted/rejected
            var permissionGranted = true
            permissions.entries.forEach {
                if (it.key in REQUIRED_PERMISSIONS && it.value == false)
                    permissionGranted = false
            }
            if (!permissionGranted) {
                Toast.makeText(baseContext,
                    "Permission request denied",
                    Toast.LENGTH_SHORT).show()
            } else {
                startCamera()
            }
        }



    private class LuminosityAnalyzer(private val listener: LumaListener) : ImageAnalysis.Analyzer {

        private fun ByteBuffer.toByteArray(): ByteArray {
            rewind()    // Rewind the buffer to zero
            val data = ByteArray(remaining())
            get(data)   // Copy the buffer into a byte array
            return data // Return the byte array
        }

        override fun analyze(image: ImageProxy) {

            val buffer = image.planes[0].buffer
            val data = buffer.toByteArray()
            val pixels = data.map { it.toInt() and 0xFF }
            val luma = pixels.average()

            listener(luma)

            image.close()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }

    companion object {
        private const val TAG = "CameraXApp"
        private const val FILENAME_FORMAT = "yyyy-MM-dd-HH-mm-ss-SSS"
        lateinit var retrofit: Retrofit
        private val REQUIRED_PERMISSIONS =
            mutableListOf (
                Manifest.permission.CAMERA,
                Manifest.permission.RECORD_AUDIO
            ).apply {
                if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                    add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                }
            }.toTypedArray()
    }
}
