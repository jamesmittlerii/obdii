package com.rheosoft.obdii.android.ui.screens

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.rheosoft.obdii.screenmodels.MilStatusScreenModel

@Composable
fun MilStatusScreen(view: MilStatusScreenModel, modifier: Modifier) {
    DisposableEffect(view) {
        view.setActive(true)
        onDispose { view.setActive(false) }
    }
    val uiState = view.viewModel.uiStateStream.collectAsState().value
    ObserveChanges(view.viewModel)
    LazyColumn(modifier = modifier.fillMaxSize().padding(16.dp)) {
        item {
            SectionLabel(view.milHeader)
            PremiumCard(modifier = Modifier.fillMaxWidth()) {
                Text(uiState.headerText, modifier = Modifier.padding(12.dp))
            }
            Spacer(Modifier.height(16.dp))
            SectionLabel(view.readinessHeader)
        }
        items(uiState.monitorRows) { row ->
            PremiumCard(modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                Row(modifier = Modifier.fillMaxWidth().padding(12.dp)) {
                    Text(row.name, modifier = Modifier.fillMaxWidth(0.7f))
                    Text(row.status, color = Color.Gray)
                }
            }
        }
    }
}
