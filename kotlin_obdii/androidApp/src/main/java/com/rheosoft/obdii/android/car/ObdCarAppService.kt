package com.rheosoft.obdii.android.car

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.util.Log
import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

class ObdCarAppService : CarAppService() {
    companion object {
        init {
            Log.d("ObdCarAppService", "Class Loaded Static")
        }
    }

    override fun createHostValidator(): HostValidator {
        Log.d("ObdCarAppService", "createHostValidator called")
        return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
    }

    override fun onCreateSession(): Session {
        Log.d("ObdCarAppService", "onCreateSession")
        return ObdCarSession()
    }
}
