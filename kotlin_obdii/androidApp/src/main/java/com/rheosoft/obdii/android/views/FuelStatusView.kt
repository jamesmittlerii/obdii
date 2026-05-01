package com.rheosoft.obdii.android.views

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.rheosoft.obdii.views.FuelContentState
import com.rheosoft.obdii.views.FuelStatusView

@Composable
fun FuelStatusScreen(view: FuelStatusView, modifier: Modifier) {
    ObserveChanges(view.viewModel)
    when (val state = view.contentState()) {
        is FuelContentState.Waiting -> CenterText(state.message, modifier)
        is FuelContentState.Empty -> CenterText(state.message, modifier)
        is FuelContentState.Data -> LazyColumn(modifier = modifier.fillMaxSize().padding(16.dp)) {
            items(state.banks) { bank ->
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
