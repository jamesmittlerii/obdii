package com.rheosoft.obdii.windows.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircleOutline
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.WarningAmber
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.unit.sp
import com.rheosoft.obdii.screenmodels.DiagnosticsContentState
import com.rheosoft.obdii.screenmodels.DiagnosticsScreenModel
import com.rheosoft.obdii.screenmodels.DtcRowModel
import com.rheosoft.obdii.screenmodels.DtcDetailScreenModel

@Composable
fun DiagnosticsScreen(view: DiagnosticsScreenModel, modifier: Modifier, onDtcTap: (DtcDetailScreenModel) -> Unit) {
    DisposableEffect(view) {
        view.setActive(active = true)
        onDispose { view.setActive(active = false) }
    }
    val uiState = view.viewModel.uiStateStream.collectAsState().value
    ObserveChanges(view.viewModel)
    when (val state = view.contentState(uiState.connectionState)) {
        is DiagnosticsContentState.Waiting -> DiagnosticsWaiting(state, modifier)
        is DiagnosticsContentState.Empty -> DiagnosticsEmpty(state, modifier)
        is DiagnosticsContentState.Sections -> DiagnosticsSections(state = state, view = view, onDtcTap = onDtcTap, modifier = modifier)
    }
}

@Composable
private fun DiagnosticsWaiting(state: DiagnosticsContentState.Waiting, modifier: Modifier) {
    Column(
        modifier = modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        CircularProgressIndicator()
        Spacer(Modifier.height(16.dp))
        Text(state.waitingText, color = Color.Gray)
        if (state.showConnectHint) {
            Spacer(Modifier.height(8.dp))
            Text(state.connectHint, color = Color.Gray)
        }
    }
}

@Composable
private fun DiagnosticsEmpty(state: DiagnosticsContentState.Empty, modifier: Modifier) {
    Column(
        modifier = modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(Icons.Outlined.CheckCircleOutline, contentDescription = null, tint = Color(0xFF2E7D32))
        Spacer(Modifier.height(16.dp))
        Text(state.title)
        Text(state.subtitle, color = Color.Gray)
    }
}

@Composable
private fun DiagnosticsSections(
    state: DiagnosticsContentState.Sections,
    view: DiagnosticsScreenModel,
    onDtcTap: (DtcDetailScreenModel) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyColumn(modifier = modifier.fillMaxSize().padding(16.dp)) {
        items(state.sections) { section ->
            SectionLabel(section.header)
            section.rows.forEach { row ->
                DiagnosticsRow(
                    row = row,
                    onClick = {
                        view.findDtc(row.code)?.let { onDtcTap(view.detailFor(it)) }
                    },
                )
            }
        }
    }
}

@Composable
private fun DiagnosticsRow(
    row: DtcRowModel,
    onClick: () -> Unit,
) {
    PremiumCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp)
            .clickable(onClick = onClick),
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                DiagnosticsRowTitle(row, modifier = Modifier.weight(1f))
                Icon(
                    imageVector = Icons.Outlined.ChevronRight,
                    contentDescription = "Details",
                    tint = Color.Gray,
                    modifier = Modifier.padding(start = 8.dp)
                )
            }
        }
    }
}

@Composable
private fun DiagnosticsRowTitle(row: DtcRowModel, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = severityIcon(row.severityIcon),
            contentDescription = null,
            tint = severityColor(row.severityIcon),
        )
        Spacer(Modifier.width(8.dp))
        Text(
            text = row.title,
            style = MaterialTheme.typography.bodyLarge
        )
    }
}

private fun DiagnosticsScreenModel.findDtc(code: String) =
    viewModel.sections
        .asSequence()
        .flatMap { it.items }
        .firstOrNull { it.code == code }

private fun severityIcon(severityIcon: String) =
    when (severityIcon) {
        "cancel_outlined", "electric_bolt", "warning_amber_outlined" -> Icons.Outlined.WarningAmber
        else -> Icons.Outlined.Info
    }

private fun severityColor(severityIcon: String): Color =
    when (severityIcon) {
        "cancel_outlined" -> Color.Red
        "electric_bolt" -> Color(0xFFFF9800)
        "warning_amber_outlined" -> Color(0xFFFFC107)
        else -> Color(0xFF2196F3)
    }

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun DtcDetailScreen(detail: DtcDetailScreenModel, onClose: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(detail.title, style = MaterialTheme.typography.headlineMedium) },
                navigationIcon = {
                    IconButton(onClick = onClose) {
                        Icon(Icons.Outlined.ChevronLeft, contentDescription = "Back")
                    }
                },
            )
        },
        containerColor = AppBackground,
    ) { pad ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(pad)
                .padding(horizontal = 16.dp)
        ) {
            item {
                detail.sectionHeaders.forEach { header ->
                    SectionLabel(header)
                    PremiumCard(modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
                        Column(modifier = Modifier.fillMaxWidth()) {
                            DtcDetailSectionContent(header, detail)
                        }
                    }
                }
                Spacer(Modifier.height(32.dp))
            }
        }
    }
}

@Composable
private fun DtcDetailSectionContent(header: String, detail: DtcDetailScreenModel) {
    when (header) {
        "Overview" -> OverviewRows(detail.overviewRows)
        "Description" -> {
            Text(
                text = detail.description,
                modifier = Modifier.padding(16.dp),
                style = MaterialTheme.typography.bodyLarge,
                lineHeight = 24.sp
            )
        }
        "Potential causes" -> BulletRows(detail.causes)
        "Possible remedies" -> BulletRows(detail.remedies)
    }
}

@Composable
private fun OverviewRows(rows: List<Pair<String, String>>) {
    rows.forEachIndexed { index, (key, value) ->
        OverviewRow(key, value)
        if (index < rows.size - 1) DetailDivider()
    }
}

@Composable
private fun OverviewRow(key: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top
    ) {
        Text(
            text = key,
            color = Color.Gray.copy(alpha = 0.6f),
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(top = 2.dp)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyLarge,
            color = overviewValueColor(key, value),
            textAlign = androidx.compose.ui.text.style.TextAlign.End,
            modifier = Modifier.weight(1f).padding(start = 16.dp)
        )
    }
}

@Composable
private fun BulletRows(values: List<String>) {
    values.forEachIndexed { index, value ->
        BulletRow(value)
        if (index < values.size - 1) DetailDivider()
    }
}

@Composable
private fun BulletRow(value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 1.dp),
        verticalAlignment = Alignment.Top
    ) {
        Text(
            text = "•",
            modifier = Modifier.padding(end = 12.dp),
            style = MaterialTheme.typography.bodyLarge.copy(fontSize = 22.sp),
            color = Color(0xFF2196F3)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.weight(1f).padding(top = 3.dp)
        )
    }
}

@Composable
private fun overviewValueColor(key: String, value: String): Color =
    if (key == "Severity") {
        severityLabelColor(value) ?: MaterialTheme.colorScheme.onSurface
    } else {
        MaterialTheme.colorScheme.onSurface
    }

private fun severityLabelColor(value: String): Color? =
    when (value) {
        "Critical" -> Color.Red
        "High" -> Color(0xFFFF9800)
        "Moderate" -> Color(0xFFFFC107)
        "Low" -> Color(0xFF2196F3)
        else -> null
    }

@Composable
private fun DetailDivider() {
    HorizontalDivider(
        modifier = Modifier.padding(horizontal = 12.dp),
        thickness = 0.5.dp,
        color = Color.LightGray.copy(alpha = 0.3f),
    )
}
