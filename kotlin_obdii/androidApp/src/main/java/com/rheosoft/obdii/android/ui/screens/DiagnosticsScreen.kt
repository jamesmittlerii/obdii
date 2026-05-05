package com.rheosoft.obdii.android.ui.screens

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
        is DiagnosticsContentState.Waiting -> Column(
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
        is DiagnosticsContentState.Empty -> Column(
            modifier = modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Icon(Icons.Outlined.CheckCircleOutline, contentDescription = null, tint = Color(0xFF2E7D32))
            Spacer(Modifier.height(16.dp))
            Text(state.title)
            Text(state.subtitle, color = Color.Gray)
        }
        is DiagnosticsContentState.Sections -> LazyColumn(modifier = modifier.fillMaxSize().padding(16.dp)) {
            items(state.sections) { section ->
                SectionLabel(section.header)
                section.rows.forEach { row ->
                    PremiumCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 8.dp)
                            .clickable {
                                val raw = view.viewModel.sections
                                    .asSequence()
                                    .flatMap { it.items }
                                    .firstOrNull { it.code == row.code }
                                raw?.let { onDtcTap(view.detailFor(it)) }
                            },
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Row(
                                    modifier = Modifier.weight(1f),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Icon(
                                        imageVector = when (row.severityIcon) {
                                            "cancel_outlined", "electric_bolt", "warning_amber_outlined" -> Icons.Outlined.WarningAmber
                                            else -> Icons.Outlined.Info
                                        },
                                        contentDescription = null,
                                        tint = when (row.severityIcon) {
                                            "cancel_outlined" -> Color.Red
                                            "electric_bolt" -> Color(0xFFFF9800)
                                            "warning_amber_outlined" -> Color(0xFFFFC107)
                                            else -> Color(0xFF2196F3)
                                        },
                                    )
                                    Spacer(Modifier.width(8.dp))
                                    Text(
                                        text = row.title,
                                        style = MaterialTheme.typography.bodyLarge
                                    )
                                }
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
            }
        }
    }
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
                            when (header) {
                                "Overview" -> {
                                    detail.overviewRows.forEachIndexed { index, (k, v) ->
                                        Row(
                                            modifier = Modifier
                                                .fillMaxWidth()
                                                .padding(horizontal = 16.dp, vertical = 8.dp),
                                            horizontalArrangement = Arrangement.SpaceBetween,
                                            verticalAlignment = Alignment.Top
                                        ) {
                                            Text(
                                                text = k,
                                                color = Color.Gray.copy(alpha = 0.6f),
                                                style = MaterialTheme.typography.bodyLarge,
                                                modifier = Modifier.padding(top = 2.dp)
                                            )
                                            val valueColor = if (k == "Severity") {
                                                when (v) {
                                                    "Critical" -> Color.Red
                                                    "High" -> Color(0xFFFF9800)
                                                    "Moderate" -> Color(0xFFFFC107)
                                                    "Low" -> Color(0xFF2196F3)
                                                    else -> MaterialTheme.colorScheme.onSurface
                                                }
                                            } else {
                                                MaterialTheme.colorScheme.onSurface
                                            }
                                            Text(
                                                text = v,
                                                style = MaterialTheme.typography.bodyLarge,
                                                color = valueColor,
                                                textAlign = androidx.compose.ui.text.style.TextAlign.End,
                                                modifier = Modifier.weight(1f).padding(start = 16.dp)
                                            )
                                        }
                                        if (index < detail.overviewRows.size - 1) {
                                            HorizontalDivider(modifier = Modifier.padding(horizontal = 12.dp), thickness = 0.5.dp, color = Color.LightGray.copy(alpha = 0.3f))
                                        }
                                    }
                                }
                                "Description" -> {
                                    Text(
                                        text = detail.description,
                                        modifier = Modifier.padding(16.dp),
                                        style = MaterialTheme.typography.bodyLarge,
                                        lineHeight = 24.sp
                                    )
                                }
                                "Potential causes" -> {
                                    detail.causes.forEachIndexed { index, cause ->
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
                                                text = cause,
                                                style = MaterialTheme.typography.bodyLarge,
                                                modifier = Modifier.weight(1f).padding(top = 3.dp)
                                            )
                                        }
                                        if (index < detail.causes.size - 1) {
                                            HorizontalDivider(modifier = Modifier.padding(horizontal = 12.dp), thickness = 0.5.dp, color = Color.LightGray.copy(alpha = 0.3f))
                                        }
                                    }
                                }
                                "Possible remedies" -> {
                                    detail.remedies.forEachIndexed { index, remedy ->
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
                                                text = remedy,
                                                style = MaterialTheme.typography.bodyLarge,
                                                modifier = Modifier.weight(1f).padding(top = 3.dp)
                                            )
                                        }
                                        if (index < detail.remedies.size - 1) {
                                            HorizontalDivider(modifier = Modifier.padding(horizontal = 12.dp), thickness = 0.5.dp, color = Color.LightGray.copy(alpha = 0.3f))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer(Modifier.height(32.dp))
            }
        }
    }
}
