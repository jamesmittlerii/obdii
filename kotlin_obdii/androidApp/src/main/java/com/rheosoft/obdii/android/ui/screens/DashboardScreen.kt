package com.rheosoft.obdii.android.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.zIndex
import com.rheosoft.obdii.core.GaugesDisplayMode
import com.rheosoft.obdii.models.PidColor
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.screenmodels.DashboardScreenModel
import com.rheosoft.obdii.viewmodels.GaugeTile
import com.rheosoft.obdii.screenmodels.RingGaugeModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlin.math.roundToInt
import kotlin.math.max

private data class GridDragMetrics(
    val columns: Int,
    val itemWidthPx: Float,
    val itemHeightPx: Float,
)

@Composable
fun DashboardScreen(
    view: DashboardScreenModel,
    isMetric: Boolean,
    modifier: Modifier,
    scope: CoroutineScope,
    onGaugeTap: (ObdiiPid) -> Unit,
) {
    val uiState by view.viewModel.uiStateStream.collectAsState()
    val enabled = uiState.tiles
    val listMode = uiState.displayMode == GaugesDisplayMode.list

    LazyColumn(modifier = modifier.fillMaxSize().padding(16.dp)) {
        item {
            SegmentedPicker(
                options = listOf("Gauges", "List"),
                selectedIndex = if (listMode) 1 else 0,
                onOptionSelected = { index ->
                    view.viewModel.setDisplayMode(if (index == 1) GaugesDisplayMode.list else GaugesDisplayMode.gauges)
                },
            )
            Spacer(Modifier.height(12.dp))
        }
        if (enabled.isEmpty()) {
            item { CenterText("No gauges enabled.\nGo to Settings -> Gauges to add some.", Modifier.fillMaxWidth().padding(top = 24.dp)) }
            return@LazyColumn
        }
        if (listMode) {
            item { SectionLabel("Gauges") }
            itemsIndexed(
                items = enabled,
                key = { _, tile -> tile.pid.stableKey() },
            ) { index, tile ->
                DashboardListRow(tile, index, isMetric, enabled, view, scope, onGaugeTap)
            }
            return@LazyColumn
        }
        item {
            DashboardGridMode(enabled, isMetric, view, scope, onGaugeTap)
        }
    }
}

@Composable
private fun DashboardListRow(
    tile: GaugeTile,
    index: Int,
    isMetric: Boolean,
    enabled: List<GaugeTile>,
    view: DashboardScreenModel,
    scope: CoroutineScope,
    onGaugeTap: (ObdiiPid) -> Unit
) {
    var draggingKey by remember { mutableStateOf<String?>(null) }
    var draggingIndex by remember { mutableStateOf<Int?>(null) }
    var draggingOffsetY by remember { mutableFloatStateOf(0f) }
    val rowHeightPx = with(LocalDensity.current) { 76.dp.toPx() } // Estimated for list row

    val gauge = RingGaugeModel(tile.pid, tile.stats?.latest?.value, isMetric)
    val valueColor = when (gauge.progressColor) {
        PidColor.GREEN -> Color(0xFF4CAF50)
        PidColor.ORANGE -> Color(0xFFFF9800)
        PidColor.RED -> Color(0xFFE53935)
        PidColor.BLUE_GREY -> Color.Gray
    }
    val isDragging = (draggingKey == tile.pid.stableKey()) && (draggingIndex == index)
    PremiumCard(
        modifier = Modifier
            .offset { IntOffset(0, if (isDragging) draggingOffsetY.roundToInt() else 0) }
            .zIndex(if (isDragging) 1f else 0f)
            .fillMaxWidth()
            .padding(bottom = 6.dp)
            .clickable { onGaugeTap(tile.pid) },
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .pointerInput(tile.pid.stableKey()) {
                    detectDragGestures(
                        onDragStart = {
                            val currentIndex = enabled.indexOfFirst { it.pid.stableKey() == tile.pid.stableKey() }
                            if (currentIndex != -1) {
                                draggingKey = tile.pid.stableKey()
                                draggingIndex = currentIndex
                                draggingOffsetY = 0f
                            }
                        },
                        onDrag = { change, dragAmount ->
                            change.consume()
                            draggingOffsetY += dragAmount.y
                            val from = draggingIndex ?: return@detectDragGestures
                            val shift = (draggingOffsetY / rowHeightPx).toInt()
                            val target = (from + shift).coerceIn(0, enabled.lastIndex)
                            if (target != from) {
                                draggingIndex = target
                                draggingOffsetY -= (target - from) * rowHeightPx
                                scope.launch { view.viewModel.moveEnabled(from, target) }
                            }
                        },
                        onDragEnd = {
                            draggingKey = null
                            draggingIndex = null
                            draggingOffsetY = 0f
                        },
                        onDragCancel = {
                            draggingKey = null
                            draggingIndex = null
                            draggingOffsetY = 0f
                        },
                    )
                }
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = tile.pid.name,
                    style = MaterialTheme.typography.bodyLarge
                )
                Text(tile.pid.displayRange(isMetric), color = Color.Gray)
            }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.End
            ) {
                Text(
                    text = tile.stats?.let { tile.pid.formattedValue(it.latest.value, isMetric, includeUnits = true) }
                        ?: "— ${tile.pid.unitLabel(isMetric)}",
                    color = valueColor,
                    textAlign = TextAlign.End,
                    style = MaterialTheme.typography.bodyLarge
                )
                Spacer(Modifier.width(4.dp))
                Icon(Icons.Outlined.ChevronRight, contentDescription = null, tint = Color.Gray)
            }
        }
    }
}

@Composable
private fun DashboardGridMode(
    enabled: List<GaugeTile>,
    isMetric: Boolean,
    view: DashboardScreenModel,
    scope: CoroutineScope,
    onGaugeTap: (ObdiiPid) -> Unit
) {
    var draggingGridKey by remember { mutableStateOf<String?>(null) }
    var draggingGridIndex by remember { mutableStateOf<Int?>(null) }
    var draggingGridOffset by remember { mutableStateOf(Offset.Zero) }

    BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
        val gridWidth = this.maxWidth
        val columns = (gridWidth / 160.dp).toInt().coerceAtLeast(1)
        val itemWidthPx = with(LocalDensity.current) { (gridWidth / columns).toPx() }
        val itemHeightPx = itemWidthPx * 1.1f // Approximate height based on aspect ratio and label

        LazyVerticalGrid(
            columns = GridCells.Fixed(columns),
            modifier = Modifier.fillMaxWidth().height(520.dp)
        ) {
            itemsIndexed(
                items = enabled,
                key = { _, tile -> tile.pid.stableKey() },
            ) { _, tile ->
                val isDragging = draggingGridKey == tile.pid.stableKey()
                GaugeGridItem(
                    tile = tile,
                    isMetric = isMetric,
                    isDragging = isDragging,
                    draggingGridOffset = draggingGridOffset,
                    onGaugeTap = onGaugeTap,
                    onDragStart = {
                        val currentIndex = enabled.indexOfFirst { it.pid.stableKey() == tile.pid.stableKey() }
                        if (currentIndex != -1) {
                            draggingGridKey = tile.pid.stableKey()
                            draggingGridIndex = currentIndex
                            draggingGridOffset = Offset.Zero
                        }
                    },
                    onDrag = { dragAmount ->
                        draggingGridOffset += dragAmount
                        val from = draggingGridIndex ?: return@GaugeGridItem
                        val move = gridDragMove(
                            from = from,
                            offset = draggingGridOffset,
                            metrics = GridDragMetrics(columns, itemWidthPx, itemHeightPx),
                            lastIndex = enabled.lastIndex,
                        )
                        if (move != null) {
                            draggingGridIndex = move
                            draggingGridOffset -= gridOffsetConsumed(from, move, columns, itemWidthPx, itemHeightPx)
                            scope.launch { view.viewModel.moveEnabled(from, move) }
                        }
                    },
                    onDragEnd = {
                        draggingGridKey = null
                        draggingGridIndex = null
                        draggingGridOffset = Offset.Zero
                    },
                )
            }
        }
    }
}

@Composable
private fun GaugeGridItem(
    tile: GaugeTile,
    isMetric: Boolean,
    isDragging: Boolean,
    draggingGridOffset: Offset,
    onGaugeTap: (ObdiiPid) -> Unit,
    onDragStart: () -> Unit,
    onDrag: (Offset) -> Unit,
    onDragEnd: () -> Unit,
) {
    PremiumCard(
        modifier = Modifier
            .offset { if (isDragging) draggingGridOffset.toIntOffset() else IntOffset.Zero }
            .zIndex(if (isDragging) 1f else 0f)
            .padding(6.dp)
            .fillMaxWidth()
            .clickable { onGaugeTap(tile.pid) }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .pointerInput(tile.pid.stableKey()) {
                    detectDragGestures(
                        onDragStart = { onDragStart() },
                        onDrag = { change, dragAmount ->
                            change.consume()
                            onDrag(dragAmount)
                        },
                        onDragEnd = onDragEnd,
                        onDragCancel = onDragEnd,
                    )
                }
                .padding(10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            RingGaugeMini(tile = tile, isMetric = isMetric, modifier = Modifier.fillMaxWidth())
            Text(tile.pid.label, fontWeight = FontWeight.SemiBold)
        }
    }
}

private fun gridDragMove(
    from: Int,
    offset: Offset,
    metrics: GridDragMetrics,
    lastIndex: Int,
): Int? {
    val colShift = (offset.x / metrics.itemWidthPx).roundToInt()
    val rowShift = (offset.y / metrics.itemHeightPx).roundToInt()
    if (colShift == 0 && rowShift == 0) return null
    val target = (from + rowShift * metrics.columns + colShift).coerceIn(0, lastIndex)
    return target.takeIf { it != from }
}

private fun gridOffsetConsumed(
    from: Int,
    target: Int,
    columns: Int,
    itemWidthPx: Float,
    itemHeightPx: Float,
): Offset = Offset(
    (target % columns - from % columns) * itemWidthPx,
    (target / columns - from / columns) * itemHeightPx,
)

private fun Offset.toIntOffset(): IntOffset =
    IntOffset(x.roundToInt(), y.roundToInt())


@Composable
private fun RingGaugeMini(tile: GaugeTile, isMetric: Boolean, modifier: Modifier = Modifier) {
    val gauge = RingGaugeModel(tile.pid, tile.stats?.latest?.value, isMetric)
    val progressColor = when (gauge.progressColor) {
        PidColor.GREEN -> Color(0xFF4CAF50)
        PidColor.ORANGE -> Color(0xFFFF9800)
        PidColor.RED -> Color(0xFFE53935)
        PidColor.BLUE_GREY -> Color.Gray
    }
    Box(
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(1f / 0.8167f),
        contentAlignment = Alignment.TopCenter,
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1f)
                .align(Alignment.TopCenter)
                .padding(top = 14.dp, start = 4.dp, end = 4.dp, bottom = 4.dp)
        ) {
            // Keep a square drawing surface so the ring is always circular.
            val strokeWidth = max(4f, size.width * 0.18f)
            val radius = (size.width / 2f) - (strokeWidth / 2f)
            val rect = androidx.compose.ui.geometry.Rect(
                left = (size.width / 2f) - radius,
                top = (size.width / 2f) - radius,
                right = (size.width / 2f) + radius,
                bottom = (size.width / 2f) + radius,
            )
            val stroke = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            drawArc(
                color = Color(0xFF7C7C82),
                startAngle = 150f,
                sweepAngle = 240f,
                useCenter = false,
                topLeft = rect.topLeft,
                size = rect.size,
                style = stroke
            )
            drawArc(
                color = progressColor,
                startAngle = 150f,
                sweepAngle = (240f * gauge.normalized).toFloat(),
                useCenter = false,
                topLeft = rect.topLeft,
                size = rect.size,
                style = stroke
            )
        }
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .align(Alignment.Center)
                .offset(y = 17.dp),
        ) {
            Text(gauge.valueLine, textAlign = TextAlign.Center, fontWeight = FontWeight.SemiBold, fontSize = 30.sp)
            Text(gauge.unitLine, textAlign = TextAlign.Center, color = Color(0xFFB1B1B6))
        }
    }
}

private fun ObdiiPid.stableKey(): String = id.ifBlank { pidCommand }
