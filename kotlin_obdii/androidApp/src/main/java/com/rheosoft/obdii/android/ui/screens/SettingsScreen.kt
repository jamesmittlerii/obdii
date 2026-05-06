package com.rheosoft.obdii.android.ui.screens

import android.content.Intent
import android.widget.Toast
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.rheosoft.obdii.core.ConnectionType
import com.rheosoft.obdii.core.MeasurementUnit
import com.rheosoft.obdii.core.OBDConnectionState
import com.rheosoft.obdii.screenmodels.SettingsScreenModel
import java.io.File

@Composable
fun SettingsScreen(
    view: SettingsScreenModel,
    modifier: Modifier,
    onOpenGaugePicker: () -> Unit,
) {
    val context = LocalContext.current
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
        runCatching {
            val p = context.packageManager.getPackageInfo(context.packageName, 0)
            val appName = context.applicationInfo.loadLabel(context.packageManager).toString()
            vm.setAppVersion("$appName v${p.versionName} build:${p.longVersionCode}")
        }
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
            SectionLabel("Units")
            PremiumCard(modifier = Modifier.fillMaxWidth()) {
                Box(modifier = Modifier.padding(10.dp)) {
                    SegmentedPicker(
                        options = listOf("Metric", "Imperial"),
                        selectedIndex = if (selectedUnits == MeasurementUnit.Metric) 0 else 1,
                        onOptionSelected = { index ->
                            val next = if (index == 0) MeasurementUnit.Metric else MeasurementUnit.Imperial
                            selectedUnits = next
                            vm.onUnitsChanged(next)
                        },
                    )
                }
            }
            Spacer(Modifier.height(6.dp))
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
                    val statusColor = when (statusLabel) {
                        "Connected" -> Color(0xFF2E7D32)
                        "Connecting..." -> Color(0xFFEF6C00)
                        "Connected to Adapter..." -> Color(0xFF1976D2)
                        "Setting up vehicle..." -> Color(0xFFEF6C00)
                        "Failed" -> Color(0xFFC62828)
                        else -> Color.Gray
                    }
                    Text(statusLabel, color = statusColor)
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
                            onClick = { typeMenuExpanded = true },
                            contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)
                        ) {
                            Text(
                                when (selectedType) {
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
                            expanded = typeMenuExpanded,
                            onDismissRequest = { typeMenuExpanded = false },
                        ) {
                            DropdownMenuItem(
                                text = { Text("Demo") },
                                onClick = {
                                    selectedType = ConnectionType.demo
                                    vm.onConnectionTypeChanged(ConnectionType.demo)
                                    typeMenuExpanded = false
                                },
                            )
                            DropdownMenuItem(
                                text = { Text("WiFi") },
                                onClick = {
                                    selectedType = ConnectionType.wifi
                                    vm.onConnectionTypeChanged(ConnectionType.wifi)
                                    typeMenuExpanded = false
                                },
                            )
                            DropdownMenuItem(
                                text = { Text("Bluetooth LE") },
                                onClick = {
                                    selectedType = ConnectionType.bluetooth
                                    vm.onConnectionTypeChanged(ConnectionType.bluetooth)
                                    typeMenuExpanded = false
                                },
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
                        checked = autoConnect,
                        onCheckedChange = {
                            autoConnect = it
                            vm.onAutoConnectChanged(it)
                        },
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
                        onClick = {
                            vm.handleConnectionButtonTap()
                        },
                        enabled = !vm.isConnectButtonDisabled,
                    ) {
                        val isConnecting = vm.connectionState == OBDConnectionState.connecting ||
                            vm.connectionState == OBDConnectionState.connectedToAdapter ||
                            vm.connectionState == OBDConnectionState.settingUpVehicle

                        if (isConnecting) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(connectButtonLabel)
                                Spacer(Modifier.width(8.dp))
                                CircularProgressIndicator(
                                    modifier = Modifier.size(14.dp),
                                    strokeWidth = 2.dp,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                        } else {
                            Text(connectButtonLabel)
                        }
                    }
                }
            }
            if (selectedType == ConnectionType.wifi) {
                Spacer(Modifier.height(6.dp))
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
                            value = uiState.wifiHost,
                            onValueChange = vm::onWifiHostChanged,
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
                            value = uiState.wifiPort.toString(),
                            onValueChange = { it.toIntOrNull()?.let(vm::onWifiPortChanged) },
                            singleLine = true,
                            modifier = Modifier.width(200.dp),
                        )
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
            SectionLabel("Diagnostics")
            PremiumCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.fillMaxWidth().clickable {
                        val payload = vm.prepareLogExport()
                        runCatching {
                            val out = File(context.cacheDir, "obdii-logs.json")
                            out.writeText(payload)
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = "application/json"
                                putExtra(Intent.EXTRA_SUBJECT, "OBDII Logs")
                                putExtra(Intent.EXTRA_TEXT, payload)
                            }
                            context.startActivity(Intent.createChooser(send, "Share Logs"))
                        }.onFailure {
                            Toast.makeText(context, "Share failed: ${it.message ?: "unknown error"}", Toast.LENGTH_SHORT).show()
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
                Text(uiState.appVersion.ifEmpty { "Loading version…" }, modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp))
            }
        }
    }
}
