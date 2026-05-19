package com.rheosoft.obdii.windows.ui.screens

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.rheosoft.obdii.core.CommandCatalog
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.models.ValueRange
import com.rheosoft.obdii.viewmodels.BaseViewModel
import com.rheosoft.obdii.viewmodels.PidToggleListViewModel
import kotlinx.coroutines.launch


@Composable
fun ObserveChanges(vm: BaseViewModel) {
    vm.changeVersion.collectAsState().value
    var tick by remember(vm) { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()
    DisposableEffect(vm) {
        val prior = vm.onChanged
        vm.onChanged = {
            scope.launch { tick++ }
            prior?.invoke()
        }
        onDispose { vm.onChanged = prior }
    }
    if (tick < 0) Text("")
}

@Composable
fun ObservePidChanges(vm: PidToggleListViewModel) {
    var tick by remember(vm) { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()
    DisposableEffect(vm) {
        val prior = vm.onChanged
        vm.onChanged = {
            scope.launch { tick++ }
            prior?.invoke()
        }
        onDispose { vm.onChanged = prior }
    }
    if (tick < 0) Text("")
}

fun defaultGaugeSeedPids(): List<ObdiiPid> = listOf(
    ObdiiPid(
        id = "rpm",
        enabled = true,
        label = "RPM",
        name = "Engine RPM",
        pidCommand = "010C",
        units = "RPM",
        typicalRange = ValueRange(700.0, 2800.0),
        warningRange = ValueRange(2800.0, 5000.0),
        dangerRange = ValueRange(5000.0, 7000.0),
        kind = ObdPidKind.gauge,
    ),
    ObdiiPid(
        id = "spd",
        enabled = true,
        label = "Speed",
        name = "Vehicle Speed",
        pidCommand = "010D",
        units = "km/h",
        typicalRange = ValueRange(0.0, 120.0),
        warningRange = ValueRange(120.0, 160.0),
        dangerRange = ValueRange(160.0, 220.0),
        kind = ObdPidKind.gauge,
    ),
    ObdiiPid(
        id = "coolant",
        enabled = false,
        label = "Coolant",
        name = "Coolant Temperature",
        pidCommand = "0105",
        units = "°C",
        typicalRange = ValueRange(80.0, 100.0),
        warningRange = ValueRange(100.0, 110.0),
        dangerRange = ValueRange(110.0, 125.0),
        kind = ObdPidKind.gauge,
    ),
)

fun loadPidsFromJson(): List<ObdiiPid> {
    return try {
        val stream = Thread.currentThread().contextClassLoader.getResourceAsStream("OBDPIDs.json") ?: return emptyList()
        val raw = stream.bufferedReader().use { it.readText() }
        val listType = object : com.google.gson.reflect.TypeToken<List<Map<String, Any>>>() {}.type
        val arr: List<Map<String, Any>> = com.google.gson.Gson().fromJson(raw, listType)
        arr.mapNotNull { obj ->
            val kind = obj["kind"] as? String ?: "gauge"
            val pidObj = obj["pid"] as? Map<*, *>
            val command = CommandCatalog.resolveCommandId(
                (pidObj?.get("command") as? String).orEmpty(),
                pidType = pidObj?.get("type") as? String,
            )
            val typical = obj["typicalRange"] as? Map<*, *>
            val warning = obj["warningRange"] as? Map<*, *>
            val danger = obj["dangerRange"] as? Map<*, *>
            
            ObdiiPid(
                id = obj["id"] as? String ?: return@mapNotNull null,
                enabled = obj["enabled"] as? Boolean ?: false,
                label = obj["label"] as? String ?: "",
                name = obj["name"] as? String ?: "",
                pidCommand = command,
                formula = (obj["formula"] as? String)?.ifBlank { null },
                units = (obj["units"] as? String)?.ifBlank { null },
                typicalRange = typical?.let { ValueRange((it["min"] as Number).toDouble(), (it["max"] as Number).toDouble()) },
                warningRange = warning?.let { ValueRange((it["min"] as Number).toDouble(), (it["max"] as Number).toDouble()) },
                dangerRange = danger?.let { ValueRange((it["min"] as Number).toDouble(), (it["max"] as Number).toDouble()) },
                notes = (obj["notes"] as? String)?.ifBlank { null },
                kind = if (kind == "status") ObdPidKind.status else ObdPidKind.gauge,
            )
        }
    } catch (e: Exception) {
        e.printStackTrace()
        emptyList()
    }
}

