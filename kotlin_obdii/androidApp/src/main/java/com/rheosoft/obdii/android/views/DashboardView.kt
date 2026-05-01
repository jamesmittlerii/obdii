package com.rheosoft.obdii.android.views

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChevronRight
import com.rheosoft.obdii.core.DefaultPidStore
import com.rheosoft.obdii.core.OBDConnectionManager
import com.rheosoft.obdii.models.PidColor
import com.rheosoft.obdii.models.ObdiiPid
import com.rheosoft.obdii.viewmodels.GaugeTile
import com.rheosoft.obdii.viewmodels.GaugesViewModel
import com.rheosoft.obdii.views.RingGaugeView
import kotlin.math.max

@Composable
fun DashboardScreen(
    vm: GaugesViewModel,
    isMetric: Boolean,
    modifier: Modifier,
    listMode: Boolean,
    onModeChanged: (Boolean) -> Unit,
    onGaugeTap: (ObdiiPid) -> Unit,
) {
    val pids by DefaultPidStore.pidsStream.collectAsState()
    val statsByPid by OBDConnectionManager.pidStatsStream.collectAsState()
    val enabled = pids
        .filter { it.enabled && it.kind == com.rheosoft.obdii.models.ObdPidKind.gauge }
        .map { GaugeTile(it.id, it, statsByPid[it.pidCommand]) }
    LazyColumn(modifier = modifier.fillMaxSize().padding(16.dp)) {
        item {
            Row {
                FilterChip(
                    selected = !listMode,
                    onClick = { onModeChanged(false) },
                    label = { Text("Gauges") },
                    modifier = Modifier.padding(end = 8.dp),
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = Color(0xFFD9E8F5),
                    ),
                )
                FilterChip(
                    selected = listMode,
                    onClick = { onModeChanged(true) },
                    label = { Text("List") },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = Color(0xFFD9E8F5),
                    ),
                )
            }
            Spacer(Modifier.height(12.dp))
        }
        if (enabled.isEmpty()) {
            item { CenterText("No gauges enabled.\nGo to Settings -> Gauges to add some.", Modifier.fillMaxWidth().padding(top = 24.dp)) }
            return@LazyColumn
        }
        if (listMode) {
            item { SectionLabel("GAUGES") }
            items(enabled) { tile ->
                val gauge = RingGaugeView(tile.pid, tile.stats?.latest?.value, isMetric)
                val valueColor = when (gauge.progressColor) {
                    PidColor.GREEN -> Color(0xFF4CAF50)
                    PidColor.ORANGE -> Color(0xFFFF9800)
                    PidColor.RED -> Color(0xFFE53935)
                    PidColor.BLUE_GREY -> Color.Gray
                }
                PremiumCard(modifier = Modifier.fillMaxWidth().padding(bottom = 6.dp).clickable { onGaugeTap(tile.pid) }) {
                    Row(Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Column(modifier = Modifier.fillMaxWidth(0.7f)) {
                            Text(tile.pid.name)
                            Text(tile.pid.displayRange(isMetric), color = Color.Gray)
                        }
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                tile.stats?.let { tile.pid.formattedValue(it.latest.value, isMetric, includeUnits = true) }
                                    ?: "— ${tile.pid.unitLabel(isMetric)}",
                                color = valueColor,
                            )
                            Spacer(Modifier.width(4.dp))
                            Icon(Icons.Outlined.ChevronRight, contentDescription = null, tint = Color.Gray)
                        }
                    }
                }
            }
            return@LazyColumn
        }
        item {
            LazyVerticalGrid(columns = GridCells.Adaptive(minSize = 160.dp), modifier = Modifier.fillMaxWidth().height(520.dp)) {
                items(enabled.size) { idx ->
                    val tile = enabled[idx]
                    PremiumCard(modifier = Modifier.padding(6.dp).fillMaxWidth().clickable { onGaugeTap(tile.pid) }) {
                        BoxWithConstraints(modifier = Modifier.fillMaxWidth().padding(10.dp)) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                RingGaugeMini(tile = tile, isMetric = isMetric, modifier = Modifier.fillMaxWidth())
                                Spacer(Modifier.height(0.dp))
                                Text(tile.pid.label, fontWeight = FontWeight.SemiBold)
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RingGaugeMini(tile: GaugeTile, isMetric: Boolean, modifier: Modifier = Modifier) {
    val gauge = RingGaugeView(tile.pid, tile.stats?.latest?.value, isMetric)
    val progressColor = when (gauge.progressColor) {
        PidColor.GREEN -> Color(0xFF4CAF50)
        PidColor.ORANGE -> Color(0xFFFF9800)
        PidColor.RED -> Color(0xFFE53935)
        PidColor.BLUE_GREY -> Color.Gray
    }
    BoxWithConstraints(modifier = modifier) {
        val dim = maxWidth
        val clippedHeight = dim * 0.8167f
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(clippedHeight)
                .clipToBounds(),
            contentAlignment = Alignment.TopCenter,
        ) {
            Canvas(modifier = Modifier.size(dim)) {
                // Keep a square drawing surface so the ring is always circular.
                val strokeWidth = max(4f, size.width * 0.18f)
                val radius = (size.width / 2f) - strokeWidth / 2f
                val rect = androidx.compose.ui.geometry.Rect(
                    left = size.width / 2f - radius,
                    top = size.width / 2f - radius,
                    right = size.width / 2f + radius,
                    bottom = size.width / 2f + radius,
                )
                val stroke = Stroke(width = strokeWidth, cap = StrokeCap.Round)
                drawArc(color = Color(0xFF7C7C82), startAngle = 150f, sweepAngle = 240f, useCenter = false, topLeft = rect.topLeft, size = rect.size, style = stroke)
                drawArc(color = progressColor, startAngle = 150f, sweepAngle = (240f * gauge.normalized).toFloat(), useCenter = false, topLeft = rect.topLeft, size = rect.size, style = stroke)
            }
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .align(Alignment.Center)
                    .offset(y = 9.dp),
            ) {
                Text(gauge.valueLine, textAlign = TextAlign.Center, fontWeight = FontWeight.SemiBold, fontSize = 30.sp)
                Text(gauge.unitLine, textAlign = TextAlign.Center, color = Color(0xFFB1B1B6))
            }
        }
    }
}
