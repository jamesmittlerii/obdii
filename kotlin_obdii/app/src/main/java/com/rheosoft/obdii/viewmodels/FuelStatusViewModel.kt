package com.rheosoft.obdii.viewmodels

import com.rheosoft.obdii.core.FuelStatusProviding
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.core.PidInterestRegistry
import com.rheosoft.obdii.core.StatusCodeMetadata
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

data class FuelStatusUiState(
    val status: List<StatusCodeMetadata?>?,
    val banks: List<Pair<String, String>>,
)

class FuelStatusViewModel(
    private val provider: FuelStatusProviding = OBDConnectionManager,
    private val interestRegistry: PidInterestRegistry = PidInterestRegistry.instance,
) : BaseViewModel() {
    private val scope = CoroutineScope(Dispatchers.Default + Job())
    private val interestToken = interestRegistry.makeToken()
    private var isVisible = false

    var status: List<StatusCodeMetadata?>? = null
        private set
    private val _statusStream = MutableStateFlow<List<StatusCodeMetadata?>?>(status)
    val statusStream: StateFlow<List<StatusCodeMetadata?>?> = _statusStream.asStateFlow()
    private val _uiStateStream = MutableStateFlow(buildUiState(status))
    val uiStateStream: StateFlow<FuelStatusUiState> = _uiStateStream.asStateFlow()

    init {
        scope.launch {
            provider.fuelStatusStream.collectLatest { s ->
                if (s != status) {
                    status = s
                    _statusStream.value = s
                    _uiStateStream.value = buildUiState(s)
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

    private fun buildUiState(status: List<StatusCodeMetadata?>?): FuelStatusUiState {
        val banks = buildList {
            status?.getOrNull(0)?.let { add("Bank 1" to it.description) }
            status?.getOrNull(1)?.let { add("Bank 2" to it.description) }
        }
        return FuelStatusUiState(status = status, banks = banks)
    }
}
