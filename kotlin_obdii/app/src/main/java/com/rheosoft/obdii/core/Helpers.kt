package com.rheosoft.obdii.core

/**
 * Swift-parity helpers entry point.
 *
 * Keep cross-cutting utility helpers grouped here to mirror Helpers.swift.
 */
object Helpers {
    fun clamp(value: Double, min: Double, max: Double): Double =
        value.coerceIn(min, max)
}
