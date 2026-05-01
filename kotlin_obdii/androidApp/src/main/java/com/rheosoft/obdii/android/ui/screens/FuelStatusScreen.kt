package com.rheosoft.obdii.android.ui.screens

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.rheosoft.obdii.screenmodels.FuelContentState
import com.rheosoft.obdii.screenmodels.FuelStatusScreenModel

@Composable
fun FuelStatusScreen(view: FuelStatusScreenModel, modifier: Modifier) {
    DisposableEffect(view) {
        view.setActive(true)
        onDispose { view.setActive(false) }
    }
    val uiState by view.viewModel.uiStateStream.collectAsState()
    ObserveChanges(view.viewModel)
    when {
        uiState.status == null -> CenterText("Waiting for data...", modifier)
        uiState.banks.isEmpty() -> CenterText("No Fuel System Status Codes", modifier)
        else -> LazyColumn(modifier = modifier.fillMaxSize().padding(16.dp)) {
            items(uiState.banks) { bank ->
                PremiumCard(modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                    Row(modifier = Modifier.fillMaxWidth().padding(12.dp)) {
                        Text(bank.first, modifier = Modifier.fillMaxWidth(0.7f))
                        Text(bank.second, color = Color.Gray)
                    }
                }
            }
        }
    }
}
