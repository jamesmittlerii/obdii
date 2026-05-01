package com.rheosoft.obdii.android.ui.screens

import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.clickable
import androidx.compose.foundation.border
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
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
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
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
    var typeMenuExpanded by remember { mutableStateOf(false) }
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
                ) {
                    Text("Gauges", modifier = Modifier.fillMaxWidth(0.85f))
                    Icon(Icons.Outlined.ChevronRight, contentDescription = null)
                }
            }
            Spacer(Modifier.height(16.dp))
            SectionLabel("UNITS")
            PremiumCard(modifier = Modifier.fillMaxWidth()) {
                BoxWithConstraints(modifier = Modifier.fillMaxWidth().padding(10.dp)) {
                    val selectedBg = Color(0xFFC5DAE7)
                    val selectedText = Color(0xFF3B4E5A)
                    val normalText = Color(0xFF222222)
                    val segmentWidth = maxWidth / 2
                    Row(modifier = Modifier.border(1.dp, Color(0xFF7E8993), shape = androidx.compose.foundation.shape.RoundedCornerShape(999.dp))) {
                        Row(
                            modifier = Modifier
                                .width(segmentWidth)
                                .background(if (selectedUnits == MeasurementUnit.Metric) selectedBg else Color.Transparent)
                                .clickable {
                                    selectedUnits = MeasurementUnit.Metric
                                    vm.onUnitsChanged(MeasurementUnit.Metric)
                                }
                                .padding(vertical = 10.dp),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(modifier = Modifier.size(18.dp), contentAlignment = Alignment.Center) {
                                if (selectedUnits == MeasurementUnit.Metric) {
                                    Icon(Icons.Outlined.Check, contentDescription = null, tint = selectedText)
                                }
                            }
                            Spacer(Modifier.width(6.dp))
                            Text("Metric", color = if (selectedUnits == MeasurementUnit.Metric) selectedText else normalText, fontWeight = FontWeight.SemiBold)
                        }
                        Row(
                            modifier = Modifier
                                .width(segmentWidth)
                                .background(if (selectedUnits == MeasurementUnit.Imperial) selectedBg else Color.Transparent)
                                .clickable {
                                    selectedUnits = MeasurementUnit.Imperial
                                    vm.onUnitsChanged(MeasurementUnit.Imperial)
                                }
                                .padding(vertical = 10.dp),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Box(modifier = Modifier.size(18.dp), contentAlignment = Alignment.Center) {
                                if (selectedUnits == MeasurementUnit.Imperial) {
                                    Icon(Icons.Outlined.Check, contentDescription = null, tint = selectedText)
                                }
                            }
                            Spacer(Modifier.width(6.dp))
                            Text("Imperial", color = if (selectedUnits == MeasurementUnit.Imperial) selectedText else normalText, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
            Spacer(Modifier.height(12.dp))
            SectionLabel("CONNECTION")
            val connectionRowMinHeight = 52.dp
            PremiumCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = connectionRowMinHeight)
                        .padding(horizontal = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("Status", modifier = Modifier.fillMaxWidth(0.7f))
                    val statusColor = when (statusLabel) {
                        "Connected" -> Color(0xFF2E7D32)
                        "Connecting..." -> Color(0xFFEF6C00)
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
                ) {
                    Text("Type", modifier = Modifier.fillMaxWidth(0.35f))
                    Box {
                        TextButton(onClick = { typeMenuExpanded = true }) {
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
                        DropdownMenu(expanded = typeMenuExpanded, onDismissRequest = { typeMenuExpanded = false }) {
                            DropdownMenuItem(text = { Text("Demo") }, onClick = {
                                selectedType = ConnectionType.demo
                                vm.onConnectionTypeChanged(ConnectionType.demo)
                                typeMenuExpanded = false
                            })
                            DropdownMenuItem(text = { Text("WiFi") }, onClick = {
                                selectedType = ConnectionType.wifi
                                vm.onConnectionTypeChanged(ConnectionType.wifi)
                                typeMenuExpanded = false
                            })
                            DropdownMenuItem(text = { Text("Bluetooth LE") }, onClick = {
                                selectedType = ConnectionType.bluetooth
                                vm.onConnectionTypeChanged(ConnectionType.bluetooth)
                                typeMenuExpanded = false
                            })
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
                ) {
                    Text("Automatically Connect", modifier = Modifier.fillMaxWidth(0.7f))
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
                    ) { Text(connectButtonLabel) }
                }
            }
            if (selectedType == ConnectionType.wifi) {
                Spacer(Modifier.height(12.dp))
                SectionLabel("CONNECTION DETAILS")
                PremiumCard(modifier = Modifier.fillMaxWidth()) {
                    Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("Host", modifier = Modifier.fillMaxWidth(0.35f))
                        OutlinedTextField(value = uiState.wifiHost, onValueChange = vm::onWifiHostChanged, singleLine = true, modifier = Modifier.fillMaxWidth())
                    }
                    HorizontalDivider()
                    Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("Port", modifier = Modifier.fillMaxWidth(0.35f))
                        OutlinedTextField(
                            value = uiState.wifiPort.toString(),
                            onValueChange = { it.toIntOrNull()?.let(vm::onWifiPortChanged) },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
            SectionLabel("DIAGNOSTICS")
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
                ) { Text(view.diagnosticsActionLabel) }
            }
            Spacer(Modifier.height(16.dp))
            SectionLabel("ABOUT")
            PremiumCard(modifier = Modifier.fillMaxWidth()) {
                Text(uiState.appVersion.ifEmpty { "Loading version…" }, modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp))
            }
        }
    }
}
