package com.rheosoft.obdii.android.ui.screens

import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
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
import androidx.compose.runtime.mutableFloatStateOf
import com.rheosoft.obdii.models.ObdPidKind
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.screenmodels.PidToggleListScreenModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

private data class PidDragState(
    val draggingKey: String?,
    val draggingEnabledIndex: Int?,
    val draggingOffsetY: Float,
)

private data class PidToggleLists(
    val enabled: List<ObdiiPid>,
    val disabled: List<ObdiiPid>,
)

private data class PidToggleListActions(
    val onToggle: (String, Boolean) -> Unit,
    val onDragStart: (String) -> Unit,
    val onDrag: (Float) -> Unit,
    val onDragEnd: () -> Unit,
)

private data class EnabledPidListItemState(
    val pid: ObdiiPid,
    val pidKey: String,
    val isMetric: Boolean,
    val isDragging: Boolean,
    val draggingOffsetY: Float,
)

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
    var draggingOffsetY by remember { mutableFloatStateOf(0f) }
    val rowHeightPx = with(LocalDensity.current) { 84.dp.toPx() }
    LaunchedEffect(vm.searchText) { searchText = vm.searchText }
    Scaffold(
        containerColor = AppBackground,
        topBar = {
            PidToggleTopBar(
                title = view.title,
                searching = searching,
                searchText = searchText,
                onSearchTextChange = {
                    searchText = it
                    vm.searchText = it
                },
                onStartSearch = {
                    searching = true
                    view.startSearch()
                },
                onCancelSearch = {
                    searching = false
                    searchText = ""
                    view.cancelSearch()
                },
                onClose = onClose,
            )
        }
    ) { pad ->
        val query = searchText.trim().lowercase()
        val enabled = visibleGaugePids(pidsSnapshot, enabled = true, query = query)
        val disabled = visibleGaugePids(pidsSnapshot, enabled = false, query = query)
        PidToggleListContent(
            modifier = Modifier.fillMaxSize().padding(pad).padding(16.dp),
            searching = searching,
            isMetric = isMetric,
            lists = PidToggleLists(enabled, disabled),
            dragState = PidDragState(draggingKey, draggingEnabledIndex, draggingOffsetY),
            actions = PidToggleListActions(
                onToggle = { pidKey, on -> scope.launch { vm.toggleById(pidKey, on) } },
                onDragStart = { pidKey ->
                    val currentIndex = enabledGaugePids(pidsSnapshot).indexOfFirst { it.stableKey() == pidKey }
                    if (currentIndex >= 0) {
                        draggingKey = pidKey
                        draggingEnabledIndex = currentIndex
                        draggingOffsetY = 0f
                    }
                },
                onDrag = { dragAmountY ->
                    draggingOffsetY += dragAmountY
                    val from = draggingEnabledIndex
                    if (from != null) {
                        val target = pidDragTarget(from, draggingOffsetY, rowHeightPx, enabled.lastIndex)
                        if (target != null) {
                            draggingEnabledIndex = target
                            draggingOffsetY -= (target - from) * rowHeightPx
                            scope.launch { vm.moveEnabled(from, target) }
                        }
                    }
                },
                onDragEnd = {
                    draggingOffsetY = 0f
                    draggingEnabledIndex = null
                    draggingKey = null
                },
            ),
        )
    }
}

@Composable
@OptIn(ExperimentalMaterial3Api::class)
private fun PidToggleTopBar(
    title: String,
    searching: Boolean,
    searchText: String,
    onSearchTextChange: (String) -> Unit,
    onStartSearch: () -> Unit,
    onCancelSearch: () -> Unit,
    onClose: () -> Unit,
) {
    TopAppBar(
        title = {
            if (searching) {
                TextField(
                    value = searchText,
                    onValueChange = onSearchTextChange,
                    singleLine = true,
                    placeholder = { Text("Search PIDs…") },
                    modifier = Modifier.fillMaxWidth(),
                )
            } else {
                Text(title)
            }
        },
        actions = {
            PidSearchAction(searching, onStartSearch, onCancelSearch)
        },
        navigationIcon = {
            IconButton(onClick = onClose) {
                Icon(Icons.Outlined.ChevronLeft, contentDescription = "Back")
            }
        },
    )
}

@Composable
private fun PidSearchAction(
    searching: Boolean,
    onStartSearch: () -> Unit,
    onCancelSearch: () -> Unit,
) {
    if (searching) {
        IconButton(onClick = onCancelSearch) {
            Icon(Icons.Outlined.Close, contentDescription = "Cancel search")
        }
    } else {
        IconButton(onClick = onStartSearch) {
            Icon(Icons.Outlined.Search, contentDescription = "Search PIDs")
        }
    }
}

@Composable
private fun PidToggleListContent(
    modifier: Modifier,
    searching: Boolean,
    isMetric: Boolean,
    lists: PidToggleLists,
    dragState: PidDragState,
    actions: PidToggleListActions,
) {
    LazyColumn(modifier = modifier) {
        if (!searching) item { Spacer(Modifier.height(2.dp)) }
        if (lists.enabled.isNotEmpty()) item { SectionLabel("Enabled") }
        itemsIndexed(
            items = lists.enabled,
            key = { _, pid -> pid.stableKey() },
        ) { enabledIndex, pid ->
            val pidKey = pid.stableKey()
            EnabledPidListItem(
                state = EnabledPidListItemState(
                    pid = pid,
                    pidKey = pidKey,
                    isMetric = isMetric,
                    isDragging = dragState.draggingKey == pidKey && dragState.draggingEnabledIndex == enabledIndex,
                    draggingOffsetY = dragState.draggingOffsetY,
                ),
                onToggle = { on -> actions.onToggle(pidKey, on) },
                onDragStart = { actions.onDragStart(pidKey) },
                onDrag = actions.onDrag,
                onDragEnd = actions.onDragEnd,
            )
        }
        if (lists.disabled.isNotEmpty()) item { SectionLabel("Disabled") }
        items(
            items = lists.disabled,
            key = { pid -> pid.stableKey() },
        ) { pid ->
            val pidKey = pid.stableKey()
            DisabledPidListItem(
                pid = pid,
                isMetric = isMetric,
                onToggle = { on -> actions.onToggle(pidKey, on) }
            )
        }
    }
}

@Composable
private fun EnabledPidListItem(
    state: EnabledPidListItemState,
    onToggle: (Boolean) -> Unit,
    onDragStart: () -> Unit,
    onDrag: (Float) -> Unit,
    onDragEnd: () -> Unit
) {
    PremiumCard(
        modifier = Modifier
            .offset { IntOffset(0, if (state.isDragging) state.draggingOffsetY.roundToInt() else 0) }
            .zIndex(if (state.isDragging) 1f else 0f)
            .fillMaxWidth()
            .padding(bottom = 8.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .pointerInput(state.pidKey) {
                    detectDragGestures(
                        onDragStart = { onDragStart() },
                        onDrag = { change, dragAmount ->
                            change.consume()
                            onDrag(dragAmount.y)
                        },
                        onDragEnd = onDragEnd,
                        onDragCancel = onDragEnd,
                    )
                }
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(state.pid.name)
                Text(state.pid.displayRange(state.isMetric), color = Color.Gray)
            }
            Switch(
                checked = state.pid.enabled,
                onCheckedChange = onToggle,
            )
        }
    }
}

@Composable
private fun DisabledPidListItem(
    pid: ObdiiPid,
    isMetric: Boolean,
    onToggle: (Boolean) -> Unit
) {
    PremiumCard(modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(pid.name)
                Text(pid.displayRange(isMetric), color = Color.Gray)
            }
            Switch(
                checked = pid.enabled,
                onCheckedChange = onToggle,
            )
        }
    }
}

private fun ObdiiPid.stableKey(): String =
    if (id.isNotBlank()) id else pidCommand

private fun enabledGaugePids(pids: List<ObdiiPid>): List<ObdiiPid> =
    pids.filter { it.enabled && it.kind == ObdPidKind.gauge }

private fun visibleGaugePids(
    pids: List<ObdiiPid>,
    enabled: Boolean,
    query: String,
): List<ObdiiPid> {
    val base = pids.filter { it.enabled == enabled && it.kind == ObdPidKind.gauge }
    return if (query.isEmpty()) base else base.filter { it.matchesQuery(query) }
}

private fun pidDragTarget(
    from: Int,
    offsetY: Float,
    rowHeightPx: Float,
    lastIndex: Int,
): Int? {
    val shift = (offsetY / rowHeightPx).toInt()
    val target = (from + shift).coerceIn(0, lastIndex)
    return target.takeIf { it != from }
}

private fun ObdiiPid.matchesQuery(query: String): Boolean =
    label.lowercase().contains(query) ||
        name.lowercase().contains(query) ||
        (notes?.lowercase()?.contains(query) == true) ||
        pidCommand.lowercase().contains(query)
