package com.rheosoft.obdii.android.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.rheosoft.obdii.android.R
import com.rheosoft.obdii.screenmodels.MilStatusScreenModel

@Composable
fun MilStatusScreen(
    view: MilStatusScreenModel,
    modifier: Modifier,
    onMilSummaryTap: () -> Unit = {},
) {
    DisposableEffect(view) {
        view.setActive(true)
        onDispose { view.setActive(false) }
    }
    val uiState = view.viewModel.uiStateStream.collectAsState().value
    ObserveChanges(view.viewModel)
    LazyColumn(modifier = modifier.fillMaxSize().padding(16.dp)) {
        item {
            SectionLabel(view.milHeader)
            PremiumCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onMilSummaryTap),
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    val milOn = uiState.status?.milOn ?: false
                    Icon(
                        painter = painterResource(id = R.drawable.ic_check_engine),
                        contentDescription = "MIL",
                        tint = if (milOn) Color(0xFFFF9800) else Color(0xFF2196F3),
                        modifier = Modifier.size(28.dp),
                    )
                    Spacer(Modifier.width(12.dp))
                    Text(uiState.headerText)
                }
            }
            Spacer(Modifier.height(16.dp))
            SectionLabel(view.readinessHeader)
        }
        items(uiState.monitorRows) { row ->
            PremiumCard(modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = Icons.Filled.Speed,
                        contentDescription = row.name,
                        tint = if (row.color == "blue") Color(0xFF2196F3) else Color(0xFFFF9800),
                        modifier = Modifier.size(22.dp),
                    )
                    Spacer(Modifier.width(12.dp))
                    Text(row.name, modifier = Modifier.weight(1f))
                    Text(row.status, color = Color.Gray)
                }
            }
        }
    }
}
