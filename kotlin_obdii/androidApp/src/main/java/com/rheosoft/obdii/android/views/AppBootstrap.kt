package com.rheosoft.obdii.android.views

import android.content.Context
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import org.json.JSONArray

@Composable
fun ObserveChanges(vm: BaseViewModel) {
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

fun loadPidsFromJson(context: Context): List<ObdiiPid> {
    return try {
        val raw = context.assets.open("OBDPIDs.json").bufferedReader().use { it.readText() }
        val arr = JSONArray(raw)
        buildList {
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val kind = obj.optString("kind", "gauge")
                val pidObj = obj.optJSONObject("pid")
                val command = CommandCatalog.resolveCommandId(
                    pidObj?.optString("command").orEmpty(),
                    pidType = pidObj?.optString("type"),
                )
                add(
                    ObdiiPid(
                        id = obj.optString("id"),
                        enabled = obj.optBoolean("enabled", false),
                        label = obj.optString("label"),
                        name = obj.optString("name"),
                        pidCommand = command,
                        formula = obj.optString("formula").ifBlank { null },
                        units = obj.optString("units").ifBlank { null },
                        typicalRange = obj.optJSONObject("typicalRange")?.let {
                            ValueRange(it.optDouble("min"), it.optDouble("max"))
                        },
                        warningRange = obj.optJSONObject("warningRange")?.let {
                            ValueRange(it.optDouble("min"), it.optDouble("max"))
                        },
                        dangerRange = obj.optJSONObject("dangerRange")?.let {
                            ValueRange(it.optDouble("min"), it.optDouble("max"))
                        },
                        notes = obj.optString("notes").ifBlank { null },
                        kind = if (kind == "status") ObdPidKind.status else ObdPidKind.gauge,
                    ),
                )
            }
        }
    } catch (_: Exception) {
        emptyList()
    }
}
