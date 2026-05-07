package com.rheosoft.obdii.android.car

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.*
import com.rheosoft.obdii.screenmodels.DtcDetailScreenModel

class DtcDetailCarScreen(carContext: CarContext, private val detail: DtcDetailScreenModel) : Screen(carContext) {

    override fun onGetTemplate(): Template {
        val paneBuilder = Pane.Builder()

        // Overview Section
        detail.overviewRows.forEach { (label, value) ->
            paneBuilder.addRow(Row.Builder()
                .setTitle(label)
                .addText(value)
                .build())
        }

        // Description Section
        paneBuilder.addRow(Row.Builder()
            .setTitle("Description")
            .addText(detail.description)
            .build())

        // Potential Causes
        if (detail.causes.isNotEmpty()) {
            val causesText = detail.causes.joinToString("\n") { "• $it" }
            paneBuilder.addRow(Row.Builder()
                .setTitle("Potential Causes")
                .addText(causesText)
                .build())
        }

        // Possible Remedies
        if (detail.remedies.isNotEmpty()) {
            val remediesText = detail.remedies.joinToString("\n") { "• $it" }
            paneBuilder.addRow(Row.Builder()
                .setTitle("Possible Remedies")
                .addText(remediesText)
                .build())
        }

        return PaneTemplate.Builder(paneBuilder.build())
            .setHeader(Header.Builder()
                .setTitle("DTC ${detail.title}")
                .setStartHeaderAction(Action.BACK)
                .build())
            .build()
    }
}
