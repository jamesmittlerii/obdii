package com.rheosoft.obdii.screenmodels

import com.rheosoft.obdii.core.ConnectionType
import com.rheosoft.obdii.core.OBDConnectionState
import com.rheosoft.obdii.viewmodels.SettingsViewModel

class SettingsScreenModel(val viewModel: SettingsViewModel) {
    val title: String = "Settings"
    val sectionHeaders: List<String>
        get() = buildList {
            add("Units")
            add("Connection")
            if (viewModel.connectionType == ConnectionType.wifi) add("Connection details")
            add("Diagnostics")
            add("About")
        }

    val unitsLabels: List<String> = listOf("Metric", "Imperial")
    val hasGaugesNavigationRow: Boolean = true
    val hasAutoConnectRow: Boolean = true
    val diagnosticsActionLabel: String = "Share Logs"
    val showIntroAgainLabel: String = "Show intro again"

    val connectButtonLabel: String
        get() = when (viewModel.connectionState) {
            OBDConnectionState.disconnected, OBDConnectionState.failed -> "Connect"
            OBDConnectionState.connecting,
            OBDConnectionState.connectedToAdapter,
            OBDConnectionState.settingUpVehicle -> "Connecting..."
            OBDConnectionState.connected -> "Disconnect"
        }

    val statusLabel: String
        get() = when (viewModel.connectionState) {
            OBDConnectionState.disconnected -> "Disconnected"
            OBDConnectionState.connecting -> "Connecting..."
            OBDConnectionState.connectedToAdapter -> "Connected to Adapter..."
            OBDConnectionState.settingUpVehicle -> "Setting up vehicle..."
            OBDConnectionState.connected -> "Connected"
            OBDConnectionState.failed -> "Failed"
        }

    val showsWifiDetails: Boolean
        get() = viewModel.connectionType == ConnectionType.wifi
}
