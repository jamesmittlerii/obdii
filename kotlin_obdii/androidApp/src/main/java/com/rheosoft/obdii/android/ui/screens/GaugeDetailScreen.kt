package com.rheosoft.obdii.android.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.rheosoft.obdii.screenmodels.GaugeDetailScreenModel

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun GaugeDetailScreen(detail: GaugeDetailScreenModel, isMetric: Boolean, onClose: () -> Unit) {
    val uiState by detail.viewModel.uiStateStream.collectAsState()
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(detail.appBarTitle) },
                navigationIcon = {
                    IconButton(onClick = onClose) {
                        Icon(Icons.Outlined.ChevronLeft, contentDescription = "Back")
                    }
                },
            )
        },
        containerColor = AppBackground
    ) { pad ->
        LazyColumn(modifier = Modifier.fillMaxSize().padding(pad).padding(16.dp)) {
            item {
                SectionLabel("Current")
                PremiumCard(modifier = Modifier.fillMaxWidth()) {
                    val stats = uiState.stats
                    val valueText = if (stats != null) {
                        detail.viewModel.pid.formattedValue(stats.latest.value, isMetric, includeUnits = true)
                    } else {
                        "— ${detail.viewModel.pid.unitLabel(isMetric)}"
                    }
                    Text(
                        text = valueText,
                        modifier = Modifier.padding(12.dp),
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
                Spacer(Modifier.height(6.dp))
                SectionLabel("Statistics")
                PremiumCard(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.fillMaxWidth()) {
                        val stats = uiState.stats
                        if (stats != null) {
                            StatRow("Min", detail.viewModel.pid.formattedValue(stats.min, isMetric, includeUnits = true))
                            HorizontalDivider(modifier = Modifier.padding(horizontal = 12.dp), thickness = 0.5.dp, color = Color.LightGray.copy(alpha = 0.3f))
                            StatRow("Max", detail.viewModel.pid.formattedValue(stats.max, isMetric, includeUnits = true))
                            HorizontalDivider(modifier = Modifier.padding(horizontal = 12.dp), thickness = 0.5.dp, color = Color.LightGray.copy(alpha = 0.3f))
                            StatRow("Samples", stats.sampleCount.toString())
                        } else {
                            Text("No data yet", color = Color.Gray, modifier = Modifier.padding(16.dp))
                        }
                    }
                }
                Spacer(Modifier.height(6.dp))
                SectionLabel("Maximum range")
                PremiumCard(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = detail.viewModel.pid.displayRange(isMetric),
                        modifier = Modifier.padding(12.dp),
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
            }
        }
    }
}

@Composable
private fun StatRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, color = Color.Gray.copy(alpha = 0.6f), style = MaterialTheme.typography.bodyLarge)
        Text(value, style = MaterialTheme.typography.bodyLarge)
    }
}
