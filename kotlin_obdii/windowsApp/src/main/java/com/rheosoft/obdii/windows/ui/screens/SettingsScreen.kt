package com.rheosoft.obdii.windows.ui.screens


import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.ButtonDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

import com.rheosoft.obdii.core.ConnectionType
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.core.OBDConnectionState
import com.rheosoft.obdii.screenmodels.SettingsScreenModel
import java.io.File

private data class ConnectionSectionState(
    val statusLabel: String,
    val selectedType: ConnectionType,
    val typeMenuExpanded: Boolean,
    val autoConnect: Boolean,
    val connectButtonLabel: String,
    val isConnectButtonDisabled: Boolean,
    val connectionState: OBDConnectionState,
)

private data class ConnectionSectionActions(
    val onTypeMenuExpandedChange: (Boolean) -> Unit,
    val onTypeSelected: (ConnectionType) -> Unit,
    val onAutoConnectChange: (Boolean) -> Unit,
    val onConnectTapped: () -> Unit,
)

@Composable
fun SettingsScreen(
    view: SettingsScreenModel,
    modifier: Modifier,
    onOpenGaugePicker: () -> Unit,
    onShowIntroAgain: () -> Unit,
) {
    val vm = view.viewModel
    val uiState by vm.uiStateStream.collectAsState()
    var typeMenuExpanded by remember { mutableStateOf(value = false) }
    var selectedUnits by remember { mutableStateOf(uiState.units) }
    var selectedType by remember { mutableStateOf(uiState.connectionType) }
    var autoConnect by remember { mutableStateOf(uiState.autoConnectToOBD) }
    LaunchedEffect(uiState.units) { selectedUnits = uiState.units }
    LaunchedEffect(uiState.connectionType) { selectedType = uiState.connectionType }
    LaunchedEffect(uiState.autoConnectToOBD) { autoConnect = uiState.autoConnectToOBD }
    val statusLabel = view.statusLabel
    val connectButtonLabel = view.connectButtonLabel

    LaunchedEffect(Unit) {
        val appVersion = System.getProperty("app.version", "0.4.18")
        val buildNum = try {
            val parts = appVersion.split('.')
            if (parts.size >= 3) {
                parts[2].toInt() * 10
            } else {
                180
            }
        } catch (e: Exception) {
            180
        }
        vm.setAppVersion("Rheosoft OBDII v$appVersion build:$buildNum")
    }
    LazyColumn(modifier = modifier.fillMaxSize().padding(16.dp)) {
        item {
            PremiumCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onOpenGaugePicker)
                        .padding(horizontal = 16.dp, vertical = 18.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text("Gauges")
                    Icon(Icons.Outlined.ChevronRight, contentDescription = null)
                }
            }
            Spacer(Modifier.height(8.dp))
            UnitsSection(selectedUnits) { next ->
                selectedUnits = next
                vm.onUnitsChanged(next)
            }
            Spacer(Modifier.height(6.dp))
            ConnectionSection(
                state = ConnectionSectionState(
                    statusLabel = statusLabel,
                    selectedType = selectedType,
                    typeMenuExpanded = typeMenuExpanded,
                    autoConnect = autoConnect,
                    connectButtonLabel = connectButtonLabel,
                    isConnectButtonDisabled = vm.isConnectButtonDisabled,
                    connectionState = vm.connectionState,
                ),
                actions = ConnectionSectionActions(
                    onTypeMenuExpandedChange = { typeMenuExpanded = it },
                    onTypeSelected = { type ->
                        selectedType = type
                        vm.onConnectionTypeChanged(type)
                        typeMenuExpanded = false
                    },
                    onAutoConnectChange = {
                        autoConnect = it
                        vm.onAutoConnectChanged(it)
                    },
                    onConnectTapped = { vm.handleConnectionButtonTap() },
                ),
            )
            if (selectedType == ConnectionType.wifi) {
                Spacer(Modifier.height(6.dp))
                ConnectionDetailsSection(
                    wifiHost = uiState.wifiHost,
                    onWifiHostChanged = vm::onWifiHostChanged,
                    wifiPort = uiState.wifiPort,
                    onWifiPortChanged = vm::onWifiPortChanged
                )
            }
            Spacer(Modifier.height(8.dp))
            SectionLabel("Diagnostics")
            PremiumCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.fillMaxWidth().clickable {
                        val payload = vm.prepareLogExport()
                        javax.swing.SwingUtilities.invokeLater {
                            val chooser = javax.swing.JFileChooser().apply {
                                dialogTitle = "Save OBDII Logs"
                                fileFilter = javax.swing.filechooser.FileNameExtensionFilter("JSON Files", "json")
                                selectedFile = File("obdii-logs.json")
                            }
                            val result = chooser.showSaveDialog(null)
                            if (result == javax.swing.JFileChooser.APPROVE_OPTION) {
                                var file = chooser.selectedFile
                                if (!file.name.endsWith(".json")) {
                                    file = File(file.absolutePath + ".json")
                                }
                                runCatching {
                                    file.writeText(payload)
                                    println("Logs saved successfully to: ${file.absolutePath}")
                                }.onFailure {
                                    println("Save failed: ${it.message ?: "unknown error"}")
                                }
                            }
                        }
                    }.padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) { 
                    Text(view.diagnosticsActionLabel)
                    Icon(Icons.Outlined.ChevronRight, contentDescription = null, tint = Color.Gray)
                }
            }
            Spacer(Modifier.height(8.dp))
            SectionLabel("About")
            PremiumCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onShowIntroAgain)
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(view.showIntroAgainLabel)
                    Icon(Icons.Outlined.ChevronRight, contentDescription = null, tint = Color.Gray)
                }
                HorizontalDivider()
                Text(uiState.appVersion.ifEmpty { "Loading version…" }, modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp))
            }
        }
    }
}

@Composable
private fun UnitsSection(selectedUnits: MeasurementUnit, onUnitsSelected: (MeasurementUnit) -> Unit) {
    SectionLabel("Units")
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        Box(modifier = Modifier.padding(10.dp)) {
            SegmentedPicker(
                options = listOf("Metric", "Imperial"),
                selectedIndex = if (selectedUnits == MeasurementUnit.Metric) 0 else 1,
                onOptionSelected = { index ->
                    onUnitsSelected(if (index == 0) MeasurementUnit.Metric else MeasurementUnit.Imperial)
                },
            )
        }
    }
}

@Composable
private fun ConnectionSection(
    state: ConnectionSectionState,
    actions: ConnectionSectionActions,
) {
    SectionLabel("Connection")
    val connectionRowMinHeight = 52.dp
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = connectionRowMinHeight)
                .padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Status")
            val statusColor = when (state.statusLabel) {
                "Connected" -> Color(0xFF2E7D32)
                "Connecting..." -> Color(0xFFEF6C00)
                "Connected to Adapter..." -> Color(0xFF1976D2)
                "Setting up vehicle..." -> Color(0xFFEF6C00)
                "Failed" -> Color(0xFFC62828)
                else -> Color.Gray
            }
            Text(state.statusLabel, color = statusColor)
        }
        HorizontalDivider()
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = connectionRowMinHeight)
                .padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Type")
            Box(contentAlignment = Alignment.CenterEnd) {
                TextButton(
                    onClick = { actions.onTypeMenuExpandedChange(true) },
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)
                ) {
                    Text(
                        when (state.selectedType) {
                            ConnectionType.demo -> "Demo"
                            ConnectionType.wifi -> "WiFi"
                            ConnectionType.bluetooth -> "Bluetooth LE"
                        },
                    )
                    Icon(
                        Icons.Outlined.ExpandMore,
                        contentDescription = "Connection type menu",
                        modifier = Modifier.padding(start = 4.dp),
                    )
                }
                DropdownMenu(
                    expanded = state.typeMenuExpanded,
                    onDismissRequest = { actions.onTypeMenuExpandedChange(false) },
                ) {
                    DropdownMenuItem(
                        text = { Text("Demo") },
                        onClick = { actions.onTypeSelected(ConnectionType.demo) },
                    )
                    DropdownMenuItem(
                        text = { Text("WiFi") },
                        onClick = { actions.onTypeSelected(ConnectionType.wifi) },
                    )
                    DropdownMenuItem(
                        text = { Text("Bluetooth LE") },
                        onClick = { actions.onTypeSelected(ConnectionType.bluetooth) },
                    )
                }
            }
        }
        HorizontalDivider()
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = connectionRowMinHeight)
                .padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Automatically Connect")
            Switch(
                checked = state.autoConnect,
                onCheckedChange = actions.onAutoConnectChange,
            )
        }
        HorizontalDivider()
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = connectionRowMinHeight)
                .padding(horizontal = 12.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(
                contentPadding = ButtonDefaults.TextButtonWithIconContentPadding,
                onClick = actions.onConnectTapped,
                enabled = !state.isConnectButtonDisabled,
            ) {
                val isConnecting = state.connectionState == OBDConnectionState.connecting ||
                    state.connectionState == OBDConnectionState.connectedToAdapter ||
                    state.connectionState == OBDConnectionState.settingUpVehicle

                if (isConnecting) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(state.connectButtonLabel)
                        Spacer(Modifier.width(8.dp))
                        CircularProgressIndicator(
                            modifier = Modifier.size(14.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                } else {
                    Text(state.connectButtonLabel)
                }
            }
        }
    }
}

@Composable
private fun ConnectionDetailsSection(
    wifiHost: String,
    onWifiHostChanged: (String) -> Unit,
    wifiPort: Int,
    onWifiPortChanged: (Int) -> Unit
) {
    SectionLabel("Connection details")
    PremiumCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Host")
            OutlinedTextField(
                value = wifiHost,
                onValueChange = onWifiHostChanged,
                singleLine = true,
                modifier = Modifier.width(200.dp),
            )
        }
        HorizontalDivider()
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("Port")
            OutlinedTextField(
                value = wifiPort.toString(),
                onValueChange = { it.toIntOrNull()?.let(onWifiPortChanged) },
                singleLine = true,
                modifier = Modifier.width(200.dp),
            )
        }
    }
}
