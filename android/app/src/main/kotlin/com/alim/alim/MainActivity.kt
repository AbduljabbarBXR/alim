package com.alim.alim

import android.content.Intent
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.Priority
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private var locationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.alim.app/location")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "turnOn" -> turnOnLocation(result)
                    else -> result.notImplemented()
                }
            }
    }

    /// Shows Android's native "turn on location" dialog when the device has
    /// location switched off. The answer arrives only after the person has
    /// made a choice, so the app can carry on without leaving Flutter.
    private fun turnOnLocation(result: MethodChannel.Result) {
        locationResult?.success(false)
        locationResult = result

        val request = LocationSettingsRequest.Builder()
            .addLocationRequest(
                LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000L).build()
            )
            .setAlwaysShow(true)
            .build()

        LocationServices.getSettingsClient(this)
            .checkLocationSettings(request)
            .addOnSuccessListener { finishLocationRequest(true) }
            .addOnFailureListener { error ->
                if (error is ResolvableApiException) {
                    try {
                        error.startResolutionForResult(this, LOCATION_SETTINGS_REQUEST)
                    } catch (_: Exception) {
                        finishLocationRequest(false)
                    }
                } else {
                    finishLocationRequest(false)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == LOCATION_SETTINGS_REQUEST) {
            // Yes or no, Dart rechecks whether the service is really on.
            finishLocationRequest(true)
        }
    }

    private fun finishLocationRequest(answer: Boolean) {
        locationResult?.success(answer)
        locationResult = null
    }

    companion object {
        private const val LOCATION_SETTINGS_REQUEST = 0x4C4F43
    }
}
