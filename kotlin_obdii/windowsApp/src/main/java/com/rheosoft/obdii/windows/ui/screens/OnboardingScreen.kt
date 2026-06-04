package com.rheosoft.obdii.windows.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.rheosoft.obdii.screenmodels.MainScaffoldScreenModel
import com.rheosoft.obdii.screenmodels.OnboardingPageKind
import com.rheosoft.obdii.screenmodels.OnboardingScreenModel

@Composable
fun OnboardingContentScrim(
    pageIndex: Int,
    onPageIndexChange: (Int) -> Unit,
    onComplete: (startDemo: Boolean) -> Unit,
) {
    val page = OnboardingScreenModel.pages[pageIndex]
    val compact = OnboardingScreenModel.usesCompactScrim(pageIndex)

    Box(modifier = Modifier.fillMaxSize()) {
        if (!compact) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.52f)),
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(0.42f)
                    .align(Alignment.TopCenter)
                    .background(Color.Black.copy(alpha = 0.2f)),
            )
        }
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.Bottom,
        ) {
            TextButton(
                onClick = { onComplete(false) },
                modifier = Modifier.align(Alignment.End),
            ) {
                Text("Skip", color = if (compact) MaterialTheme.colorScheme.onSurface else Color.White)
            }
            PremiumCard(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text(page.title, style = MaterialTheme.typography.headlineSmall)
                    Spacer(Modifier.height(10.dp))
                    Text(page.body, style = MaterialTheme.typography.bodyLarge)
                    OnboardingPageHints(pageIndex)
                    if (OnboardingScreenModel.showWelcomeSummary(pageIndex)) {
                        Spacer(Modifier.height(14.dp))
                        OnboardingWelcomeSummary()
                    }
                    Spacer(Modifier.height(16.dp))
                    OnboardingPageIndicators(pageIndex)
                    Spacer(Modifier.height(16.dp))
                    OnboardingActions(
                        pageIndex = pageIndex,
                        onPageIndexChange = onPageIndexChange,
                        onComplete = onComplete,
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
fun OnboardingNavHighlight(highlightedIndex: Int?) {
    if (highlightedIndex == null) return
    val highlightColor = MaterialTheme.colorScheme.primary
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .height(56.dp)
            .padding(horizontal = 4.dp, vertical = 6.dp),
    ) {
        MainScaffoldScreenModel.destinations.indices.forEach { idx ->
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .padding(horizontal = 2.dp),
                contentAlignment = Alignment.Center,
            ) {
                if (idx == highlightedIndex) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .clip(RoundedCornerShape(12.dp))
                            .border(2.5.dp, highlightColor, RoundedCornerShape(12.dp))
                            .background(highlightColor.copy(alpha = 0.12f)),
                    )
                }
            }
        }
    }
}

@Composable
private fun OnboardingPageHints(pageIndex: Int) {
    when (OnboardingScreenModel.pages.getOrNull(pageIndex)?.kind) {
        OnboardingPageKind.TabTour -> {
            if (OnboardingScreenModel.isGaugesDashboardPage(pageIndex)) {
                Spacer(Modifier.height(14.dp))
                OnboardingGaugesLayoutHint()
            }
        }
        OnboardingPageKind.GaugePicker -> {
            Spacer(Modifier.height(14.dp))
            OnboardingGaugePickerHint()
        }
        else -> Unit
    }
}

@Composable
private fun OnboardingGaugesLayoutHint() {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Ring vs list", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
        SegmentedPicker(
            options = listOf("Gauges", "List"),
            selectedIndex = 0,
            onOptionSelected = {},
        )
        OnboardingHintBullet("Gauges shows circular ring tiles; List shows compact rows.")
        OnboardingHintBullet("Drag a gauge on the dashboard to reorder in either view.")
    }
}

@Composable
private fun OnboardingGaugePickerHint() {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("On this screen", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
        OnboardingHintBullet("Use switches to enable or disable gauges.")
        OnboardingHintBullet("Drag rows under Enabled to set dashboard order.")
        OnboardingHintBullet("Search finds any PID in the library.")
    }
}

@Composable
private fun OnboardingHintBullet(text: String) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text("• ", fontWeight = FontWeight.Bold)
        Text(text, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun OnboardingWelcomeSummary() {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            "What you can do",
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
        )
        OnboardingScreenModel.welcomeSummaryPoints.forEach { point ->
            OnboardingHintBullet(point)
        }
    }
}

@Composable
private fun OnboardingPageIndicators(selectedIndex: Int) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
    ) {
        OnboardingScreenModel.pages.indices.forEach { index ->
            val selected = index == selectedIndex
            Box(
                modifier = Modifier
                    .padding(horizontal = 4.dp)
                    .size(if (selected) 10.dp else 8.dp)
                    .clip(CircleShape)
                    .background(
                        if (selected) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.25f),
                    ),
            )
        }
    }
}

@Composable
private fun OnboardingActions(
    pageIndex: Int,
    onPageIndexChange: (Int) -> Unit,
    onComplete: (startDemo: Boolean) -> Unit,
) {
    when {
        OnboardingScreenModel.isDemoPage(pageIndex) -> {
            Button(
                onClick = { onComplete(true) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Try Demo")
            }
            Spacer(Modifier.height(8.dp))
            TextButton(
                onClick = { onComplete(false) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Get started without Demo")
            }
        }
        OnboardingScreenModel.isLastPage(pageIndex) -> Unit
        else -> {
            Button(
                onClick = { onPageIndexChange(pageIndex + 1) },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Next")
            }
        }
    }
}
