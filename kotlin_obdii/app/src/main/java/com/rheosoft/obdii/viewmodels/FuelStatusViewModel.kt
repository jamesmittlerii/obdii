package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.FuelStatusProviding
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.StatusCodeMetadata
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

class FuelStatusViewModel(
    private val provider: FuelStatusProviding = OBDConnectionManager,
    private val interestRegistry: PidInterestRegistry = PidInterestRegistry.instance,
) : BaseViewModel() {
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private val interestToken = interestRegistry.makeToken()
    private var isVisible = false

    var status: List<StatusCodeMetadata?>? = null
        private set

    init {
        scope.launch {
            provider.fuelStatusStream.collectLatest { s ->
                if (s != status) {
                    status = s
                    notifyChanged()
                }
            }
        }
    }

    fun setVisible(visible: Boolean) {
        if (isVisible == visible) return
        isVisible = visible
        if (visible) interestRegistry.replace(setOf("0103"), interestToken) else scope.launch { interestRegistry.clear(interestToken) }
    }

    val bank1: StatusCodeMetadata?
        get() = status?.getOrNull(0)
    val bank2: StatusCodeMetadata?
        get() = status?.getOrNull(1)
    val hasAnyStatus: Boolean
        get() = status?.any { it != null } == true
}
