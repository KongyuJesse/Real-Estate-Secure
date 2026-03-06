package com.example.gradecalculator.console

data class GradeBand(
    val minimumPercentageInclusive: Double,
    val label: String,
)

class GradeScale(private val bands: List<GradeBand>) {
    init {
        require(bands.isNotEmpty()) { "Grade bands cannot be empty." }
        require(bands.zipWithNext().all { (left, right) ->
            left.minimumPercentageInclusive >= right.minimumPercentageInclusive
        }) {
            "Grade bands must be sorted from highest minimum percentage to lowest."
        }
    }

    fun gradeFor(percentage: Double): String {
        val normalized = percentage.coerceIn(0.0, 100.0)
        return bands.firstOrNull { normalized >= it.minimumPercentageInclusive }?.label ?: "F"
    }

    companion object {
        /**
         * Default plus/minus grading scale.
         *
         * Source baseline:
         * - Johns Hopkins School of Nursing (2024): A+ 97-100, A 93-96, A- 90-92, ..., D- 60-62, F < 60.
         */
        fun defaultUsPlusMinus(): GradeScale = GradeScale(
            listOf(
                GradeBand(97.0, "A+"),
                GradeBand(93.0, "A"),
                GradeBand(90.0, "A-"),
                GradeBand(87.0, "B+"),
                GradeBand(83.0, "B"),
                GradeBand(80.0, "B-"),
                GradeBand(77.0, "C+"),
                GradeBand(73.0, "C"),
                GradeBand(70.0, "C-"),
                GradeBand(67.0, "D+"),
                GradeBand(63.0, "D"),
                GradeBand(60.0, "D-"),
                GradeBand(0.0, "F"),
            ),
        )
    }
}
