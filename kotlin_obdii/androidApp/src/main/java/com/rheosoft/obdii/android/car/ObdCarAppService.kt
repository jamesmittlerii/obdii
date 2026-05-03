package com.rheosoft.obdii.android.car

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.util.Log
import androidx.car.app.CarAppService
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

import com.rheosoft.obdii.core.LogCategory
import com.rheosoft.obdii.core.ObdLogger

class ObdCarAppService : CarAppService() {
    companion object {
        init {
            ObdLogger.log("Class Loaded Static", LogCategory.App, "debug")
        }
    }

    override fun createHostValidator(): HostValidator {
        ObdLogger.log("createHostValidator called", LogCategory.App, "debug")
        return HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
    }

    override fun onCreateSession(): Session {
        ObdLogger.log("onCreateSession", LogCategory.App, "debug")
        return ObdCarSession()
    }
}
