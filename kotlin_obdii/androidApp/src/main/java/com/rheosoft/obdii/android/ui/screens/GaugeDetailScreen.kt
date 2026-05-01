package com.rheosoft.obdii.android.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.rheosoft.obdii.screenmodels.GaugeDetailScreenModel

@Composable
@OptIn(ExperimentalMaterial3Api::class)
fun GaugeDetailScreen(detail: GaugeDetailScreenModel, isMetric: Boolean, onClose: () -> Unit) {
    val uiState by detail.viewModel.uiStateStream.collectAsState()
    Scaffold(topBar = { TopAppBar(title = { Text(detail.appBarTitle) }) }, containerColor = AppBackground) { pad ->
        LazyColumn(modifier = Modifier.fillMaxSize().padding(pad).padding(16.dp)) {
            item {
                TextButton(onClick = onClose) { Text("Back") }
                SectionLabel("CURRENT")
                PremiumCard(modifier = Modifier.fillMaxWidth()) {
                    Text(detail.currentValueText, modifier = Modifier.padding(12.dp))
                }
                Spacer(Modifier.height(12.dp))
                SectionLabel("STATISTICS")
                PremiumCard(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(12.dp)) {
                        val stats = uiState.stats
                        if (stats != null) {
                            Text("Min: ${detail.viewModel.pid.formattedValue(stats.min, isMetric, includeUnits = true)}")
                            Text("Max: ${detail.viewModel.pid.formattedValue(stats.max, isMetric, includeUnits = true)}")
                            Text("Samples: ${stats.sampleCount}")
                        } else {
                            Text("No data yet", color = Color.Gray)
                        }
                    }
                }
                Spacer(Modifier.height(12.dp))
                SectionLabel("MAXIMUM RANGE")
                PremiumCard(modifier = Modifier.fillMaxWidth()) {
                    Text(detail.viewModel.pid.displayRange(isMetric), modifier = Modifier.padding(12.dp))
                }
            }
        }
    }
}
