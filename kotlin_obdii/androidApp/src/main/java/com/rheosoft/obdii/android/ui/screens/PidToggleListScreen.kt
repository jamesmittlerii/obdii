package com.rheosoft.obdii.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.DragIndicator
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.zIndex
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.gestures.detectDragGestures
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.screenmodels.PidToggleListScreenModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun PidToggleListScreen(
    view: PidToggleListScreenModel,
    isMetric: Boolean,
    onClose: () -> Unit,
    scope: CoroutineScope,
) {
    val vm = view.viewModel
    ObservePidChanges(vm)
    val pidsSnapshot by vm.pidsStream.collectAsState()
    var searching by remember { mutableStateOf(false) }
    var searchText by remember { mutableStateOf(vm.searchText) }
    var draggingKey by remember { mutableStateOf<String?>(null) }
    var draggingEnabledIndex by remember { mutableStateOf<Int?>(null) }
    var draggingOffsetY by remember { mutableStateOf(0f) }
    val rowHeightPx = with(LocalDensity.current) { 84.dp.toPx() }
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
                        Text(view.title)
                    }
                },
                actions = {
                    if (searching) {
                        IconButton(onClick = {
                            searching = false
                            searchText = ""
                            view.cancelSearch()
                        }) {
                            Icon(Icons.Outlined.Close, contentDescription = "Cancel search")
                        }
                    } else {
                        IconButton(onClick = {
                            searching = true
                            view.startSearch()
                        }) {
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
        val query = searchText.trim().lowercase()
        val enabledBase = pidsSnapshot.filter { it.enabled && it.kind == ObdPidKind.gauge }
        val disabledBase = pidsSnapshot.filter { !it.enabled && it.kind == ObdPidKind.gauge }
        val enabled = if (query.isEmpty()) enabledBase else enabledBase.filter { it.matchesQuery(query) }
        val disabled = if (query.isEmpty()) disabledBase else disabledBase.filter { it.matchesQuery(query) }
        LazyColumn(modifier = Modifier.fillMaxSize().padding(pad).padding(16.dp)) {
            if (!searching) item { Spacer(Modifier.height(2.dp)) }
            if (enabled.isNotEmpty()) item { SectionLabel("ENABLED") }
            itemsIndexed(
                items = enabled,
                key = { _, pid -> pid.stableKey() },
            ) { enabledIndex, pid ->
                val pidKey = pid.stableKey()
                val isDragging = draggingKey == pidKey && draggingEnabledIndex == enabledIndex
                PremiumCard(
                    modifier = Modifier
                        .offset { IntOffset(0, if (isDragging) draggingOffsetY.roundToInt() else 0) }
                        .zIndex(if (isDragging) 1f else 0f)
                        .fillMaxWidth()
                        .padding(bottom = 8.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .pointerInput(pidKey) {
                                detectDragGestures(
                                    onDragStart = {
                                        val currentEnabled = pidsSnapshot
                                            .filter { it.enabled && it.kind == ObdPidKind.gauge }
                                        val currentIndex =
                                            currentEnabled.indexOfFirst { it.stableKey() == pidKey }
                                        if (currentIndex < 0) return@detectDragGestures
                                        draggingKey = pidKey
                                        draggingEnabledIndex = currentIndex
                                        draggingOffsetY = 0f
                                    },
                                    onDrag = { change, dragAmount ->
                                        change.consume()
                                        draggingOffsetY += dragAmount.y
                                        val from = draggingEnabledIndex ?: return@detectDragGestures
                                        val shift = (draggingOffsetY / rowHeightPx).toInt()
                                        val target = (from + shift).coerceIn(0, enabled.lastIndex)
                                        if (target != from) {
                                            draggingEnabledIndex = target
                                            draggingOffsetY -= (target - from) * rowHeightPx
                                            scope.launch { vm.moveEnabled(from, target) }
                                        }
                                    },
                                    onDragEnd = {
                                        draggingOffsetY = 0f
                                        draggingEnabledIndex = null
                                        draggingKey = null
                                    },
                                    onDragCancel = {
                                        draggingOffsetY = 0f
                                        draggingEnabledIndex = null
                                        draggingKey = null
                                    },
                                )
                            }
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
                            tint = if (isDragging) Color(0xFF1976D2) else Color.Gray,
                            modifier = Modifier.padding(end = 6.dp),
                        )
                        Switch(
                            checked = pid.enabled,
                            onCheckedChange = { on -> scope.launch { vm.toggleById(pidKey, on) } },
                        )
                    }
                }
            }
            if (disabled.isNotEmpty()) item { SectionLabel("DISABLED") }
            items(
                items = disabled,
                key = { pid -> pid.stableKey() },
            ) { pid ->
                val pidKey = pid.stableKey()
                PremiumCard(modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.fillMaxWidth(0.75f)) {
                            Text(pid.name)
                            Text(pid.displayRange(isMetric), color = Color.Gray)
                        }
                        Switch(
                            checked = pid.enabled,
                            onCheckedChange = { on -> scope.launch { vm.toggleById(pidKey, on) } },
                        )
                    }
                }
            }
        }
    }
}

private fun com.rheosoft.obdii.models.ObdiiPid.stableKey(): String =
    if (id.isNotBlank()) id else pidCommand

private fun ObdiiPid.matchesQuery(query: String): Boolean =
    label.lowercase().contains(query) ||
        name.lowercase().contains(query) ||
        (notes?.lowercase()?.contains(query) == true) ||
        pidCommand.lowercase().contains(query)
