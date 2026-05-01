package com.rheosoft.obdii.android.views

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
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.rheosoft.obdii.views.MilLampState
import com.rheosoft.obdii.views.MilStatusView

@Composable
fun MilStatusScreen(view: MilStatusView, modifier: Modifier) {
    ObserveChanges(view.viewModel)
    LazyColumn(modifier = modifier.fillMaxSize().padding(16.dp)) {
        item {
            SectionLabel(view.milHeader)
            PremiumCard(modifier = Modifier.fillMaxWidth()) {
                val text = when (val lamp = view.milContentState()) {
                    is MilLampState.Waiting -> lamp.message
                    is MilLampState.Empty -> lamp.message
                    is MilLampState.Value -> lamp.text
                }
                Text(text, modifier = Modifier.padding(12.dp))
            }
            Spacer(Modifier.height(16.dp))
            SectionLabel(view.readinessHeader)
        }
        items(view.monitorRows()) { row ->
            PremiumCard(modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                Row(modifier = Modifier.fillMaxWidth().padding(12.dp)) {
                    Text(row.name, modifier = Modifier.fillMaxWidth(0.7f))
                    Text(row.status, color = Color.Gray)
                }
            }
        }
    }
}
