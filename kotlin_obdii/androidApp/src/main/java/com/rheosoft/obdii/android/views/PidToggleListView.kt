package com.rheosoft.obdii.android.views

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.DragIndicator
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.viewmodels.PidToggleListViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun PidToggleListScreen(
    vm: PidToggleListViewModel,
    isMetric: Boolean,
    onClose: () -> Unit,
    scope: CoroutineScope,
) {
    ObservePidChanges(vm)
    var searching by remember { mutableStateOf(false) }
    var searchText by remember { mutableStateOf(vm.searchText) }
    LaunchedEffect(vm.searchText) { searchText = vm.searchText }
    Scaffold(
        containerColor = AppBackground,
        topBar = {
            TopAppBar(
                title = {
                    if (searching) {
                        TextField(
                            value = searchText,
                            onValueChange = {
                                searchText = it
                                vm.searchText = it
                            },
                            singleLine = true,
                            placeholder = { Text("Search PIDs…") },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    } else {
                        Text("Gauges")
                    }
                },
                actions = {
                    if (searching) {
                        IconButton(onClick = {
                            searching = false
                            searchText = ""
                            vm.searchText = ""
                        }) {
                            Icon(Icons.Outlined.Close, contentDescription = "Cancel search")
                        }
                    } else {
                        IconButton(onClick = { searching = true }) {
                            Icon(Icons.Outlined.Search, contentDescription = "Search PIDs")
                        }
                    }
                },
                navigationIcon = {
                    TextButton(onClick = onClose) { Text("Back") }
                },
            )
        },
    ) { pad ->
        val enabled = vm.filteredEnabled
        val disabled = vm.filteredDisabled
        LazyColumn(modifier = Modifier.fillMaxSize().padding(pad).padding(16.dp)) {
            if (!searching) item { Spacer(Modifier.height(2.dp)) }
            if (enabled.isNotEmpty()) item { SectionLabel("ENABLED") }
            items(
                items = enabled,
                key = { pid -> if (pid.id.isNotBlank()) pid.id else pid.pidCommand },
            ) { pid ->
                val enabledIndex = vm.pids.filter { it.kind == ObdPidKind.gauge && it.enabled }.indexOfFirst { it.id == pid.id }
                var dragDelta by remember(pid.id) { mutableStateOf(0f) }
                PremiumCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 8.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .pointerInput(pid.id, enabledIndex, vm.pids) {
                                detectDragGesturesAfterLongPress(
                                    onDrag = { change, dragAmount ->
                                        change.consume()
                                        dragDelta += dragAmount.y
                                        if (dragDelta < -28f && enabledIndex > 0) {
                                            dragDelta = 0f
                                            scope.launch { vm.moveEnabled(enabledIndex, enabledIndex - 1) }
                                        } else if (dragDelta > 28f) {
                                            val max = vm.pids.count { it.kind == ObdPidKind.gauge && it.enabled } - 1
                                            if (enabledIndex in 0 until max) {
                                                dragDelta = 0f
                                                scope.launch { vm.moveEnabled(enabledIndex, enabledIndex + 1) }
                                            }
                                        }
                                    },
                                    onDragEnd = { dragDelta = 0f },
                                    onDragCancel = { dragDelta = 0f },
                                )
                            }
                            .clickable { scope.launch { vm.toggleById(pid.id, !pid.enabled) } }
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.fillMaxWidth(0.72f)) {
                            Text(pid.name)
                            Text(pid.displayRange(isMetric), color = Color.Gray)
                        }
                        Icon(
                            Icons.Outlined.DragIndicator,
                            contentDescription = "Reorder",
                            tint = Color.Gray,
                            modifier = Modifier.padding(end = 6.dp),
                        )
                        Switch(
                            checked = pid.enabled,
                            onCheckedChange = { on -> scope.launch { vm.toggleById(pid.id, on) } },
                        )
                    }
                }
            }
            if (disabled.isNotEmpty()) item { SectionLabel("DISABLED") }
            items(
                items = disabled,
                key = { pid -> if (pid.id.isNotBlank()) pid.id else pid.pidCommand },
            ) { pid ->
                PremiumCard(modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { scope.launch { vm.toggleById(pid.id, !pid.enabled) } }
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.fillMaxWidth(0.75f)) {
                            Text(pid.name)
                            Text(pid.displayRange(isMetric), color = Color.Gray)
                        }
                        Switch(
                            checked = pid.enabled,
                            onCheckedChange = { on -> scope.launch { vm.toggleById(pid.id, on) } },
                        )
                    }
                }
            }
        }
    }
}
