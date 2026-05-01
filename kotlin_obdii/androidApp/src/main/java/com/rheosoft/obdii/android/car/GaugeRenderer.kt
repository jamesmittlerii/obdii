package com.rheosoft.obdii.android.car

import android.graphics.*
import androidx.car.app.model.CarIcon
import androidx.core.graphics.drawable.IconCompat
import com.rheosoft.obdii.models.PidColor
import com.rheosoft.obdii.screenmodels.RingGaugeModel

object GaugeRenderer {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }

    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }

    fun render(gauge: RingGaugeModel, size: Int): CarIcon {
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val rect = RectF(0f, 0f, size.toFloat(), size.toFloat())
        
        val strokeWidth = size * 0.12f
        rect.inset(strokeWidth / 2f + 2f, strokeWidth / 2f + 2f)
        
        paint.strokeWidth = strokeWidth

        // Draw background arc (dark grey)
        paint.color = Color.DKGRAY
        canvas.drawArc(rect, 140f, 260f, false, paint)

        // Draw progress arc
        val progressColor = when (gauge.progressColor) {
            PidColor.GREEN -> 0xFF4CAF50.toInt()
            PidColor.ORANGE -> 0xFFFF9800.toInt()
            PidColor.RED -> 0xFFE53935.toInt()
            PidColor.BLUE_GREY -> Color.GRAY
        }
        paint.color = progressColor
        canvas.drawArc(rect, 140f, (260f * gauge.normalized).toFloat(), false, paint)

        // Draw Value
        textPaint.color = Color.WHITE
        textPaint.textSize = size * 0.28f
        // Center text vertically
        val valueY = (size / 2f) - ((textPaint.descent() + textPaint.ascent()) / 2f)
        canvas.drawText(gauge.valueLine, size / 2f, valueY - (size * 0.05f), textPaint)
        
        // Draw Unit
        textPaint.color = Color.LTGRAY
        textPaint.textSize = size * 0.12f
        canvas.drawText(gauge.unitLine, size / 2f, valueY + (size * 0.15f), textPaint)

        return CarIcon.Builder(IconCompat.createWithBitmap(bitmap)).build()
    }
}
