package com.rheosoft.obdii.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

val AppBackground = Color(0xFFF3F5FA)
private val PremiumCardColor = Color(0xFFF6F7FB)
private val PremiumCardBorder = Color(0x1A172033)

@Composable
fun SegmentedPicker(
    options: List<String>,
    selectedIndex: Int,
    onOptionSelected: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val selectedBg = Color(0xFFC5DAE7)
    val selectedText = Color(0xFF3B4E5A)
    val normalText = Color(0xFF222222)

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .border(1.dp, Color(0xFF7E8993), shape = RoundedCornerShape(999.dp)),
    ) {
        options.forEachIndexed { index, label ->
            Row(
                modifier = Modifier
                    .weight(1f)
                    .background(
                        if (selectedIndex == index) selectedBg else Color.Transparent,
                        shape = when (index) {
                            0 -> RoundedCornerShape(topStart = 999.dp, bottomStart = 999.dp)
                            options.size - 1 -> RoundedCornerShape(topEnd = 999.dp, bottomEnd = 999.dp)
                            else -> RoundedCornerShape(0.dp)
                        },
                    )
                    .clickable { onOptionSelected(index) }
                    .padding(vertical = 10.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(modifier = Modifier.size(18.dp), contentAlignment = Alignment.Center) {
                    if (selectedIndex == index) {
                        Icon(Icons.Outlined.Check, contentDescription = null, tint = selectedText)
                    }
                }
                Spacer(Modifier.width(6.dp))
                Text(
                    label,
                    color = if (selectedIndex == index) selectedText else normalText,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

@Composable
fun SectionLabel(label: String) {
    Text(
        label, // Removed .uppercase()
        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Medium),
        color = Color.Gray,
        modifier = Modifier.padding(top = 16.dp, bottom = 8.dp),
    )
}

@Composable
fun CenterText(text: String, modifier: Modifier) {
    Column(
        modifier = modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(text, color = Color.Gray)
    }
}

@Composable
fun PremiumCard(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = PremiumCardColor),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
        border = androidx.compose.foundation.BorderStroke(1.dp, PremiumCardBorder),
    ) {
        content()
    }
}
