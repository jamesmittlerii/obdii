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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.material3.Icon
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
                            Row(verticalAlignment = Alignment.CenterVertically) {
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
                                Text(row.title)
                            }
                            Text(row.subtitle, color = Color.Gray)
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
        topBar = { TopAppBar(title = { Text(detail.title) }) },
        containerColor = AppBackground,
    ) { pad ->
        LazyColumn(modifier = Modifier.fillMaxSize().padding(pad).padding(16.dp)) {
            item {
                TextButton(onClick = onClose) { Text("Back") }
                detail.sectionHeaders.forEach { header ->
                    SectionLabel(header)
                    PremiumCard(modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            when (header) {
                                "Overview" -> detail.overviewRows.forEach { (k, v) -> Text("$k: $v") }
                                "Description" -> Text(detail.description)
                                "Potential causes" -> detail.causes.forEach { Text("• $it") }
                                "Possible remedies" -> detail.remedies.forEach { Text("• $it") }
                            }
                        }
                    }
                }
            }
        }
    }
}
