package com.example.assignment4

import java.util.Locale

interface HasScores {
    val scores: List<Int>

    fun averageScore(): Double? = scores.averageOrNull()
}

open class Person(open val name: String)

data class Student(
    override val name: String,
    override val scores: List<Int>,
) : Person(name), HasScores

sealed class GradeResult {
    data class Passed(val average: Double) : GradeResult()
    data class Failed(val average: Double) : GradeResult()
    object NoScores : GradeResult()
}

fun List<Int>.averageOrNull(): Double? =
    takeIf { it.isNotEmpty() }?.let { values ->
        val total = values.fold(0) { acc, score -> acc + score }
        total / values.size.toDouble()
    }

fun scores(vararg scores: Int): List<Int> = scores.toList()

fun students(vararg students: Student): List<Student> = students.toList()

infix fun String.startsWithAny(initials: Set<Char>): Boolean {
    val first = firstOrNull()?.uppercaseChar() ?: return false
    val normalizedInitials = initials.map { it.uppercaseChar() }.toSet()
    return first in normalizedInitials
}

fun selectStudents(
    students: List<Student>,
    initials: Set<Char> = setOf('A', 'B'),
    selector: (Student) -> Boolean = { true },
): List<Student> = students
    .filter { student -> student.name startsWithAny initials }
    .filter(selector)

fun <T : Comparable<T>> maxOf(list: List<T>): T? =
    list.fold(null as T?) { currentMax, item ->
        when {
            currentMax == null -> item
            item > currentMax -> item
            else -> currentMax
        }
    }

fun classifyStudent(student: Student, passThreshold: Double = 60.0): GradeResult {
    val average = student.averageScore() ?: return GradeResult.NoScores
    return if (average >= passThreshold) {
        GradeResult.Passed(average)
    } else {
        GradeResult.Failed(average)
    }
}

fun formatAverage(average: Double): String =
    String.format(Locale.US, "%.1f", average)

fun formatStudentResult(student: Student, result: GradeResult): String = when (result) {
    is GradeResult.Passed -> "${student.name}: passed with ${formatAverage(result.average)}"
    is GradeResult.Failed -> "${student.name}: failed with ${formatAverage(result.average)}"
    GradeResult.NoScores -> "${student.name}: no scores"
}

fun <T> List<T>.formatWith(
    transform: (T) -> String,
    separator: String = "\n",
): String = map(transform).joinToString(separator)

fun buildStudentReport(
    students: List<Student>,
    initials: Set<Char> = setOf('A', 'B'),
    passThreshold: Double = 60.0,
    selector: (Student) -> Boolean = { true },
): String {
    val matchingStudents = selectStudents(students, initials, selector)
    val results = matchingStudents.map { student ->
        student to classifyStudent(student, passThreshold = passThreshold)
    }
    val topAverage = maxOf(matchingStudents.mapNotNull { it.averageScore() })
    val summaryLines = results.map { (student, result) -> formatStudentResult(student, result) }

    val topLine = if (topAverage == null) {
        "Top average: N/A"
    } else {
        "Top average: ${formatAverage(topAverage)}"
    }

    return summaryLines
        .plus(topLine)
        .formatWith(transform = { it })
}

fun main() {
    val students = students(
        Student("Alice", scores(85, 90, 88)),
        Student("Bob", scores(70, 65, 72)),
        Student("Charlie", scores(50, 45, 55)),
        Student("Anita", scores(95, 92, 94)),
        Student("Ben", scores()),
    )

    val report = buildStudentReport(
        students = students,
        initials = setOf('A', 'B'),
        passThreshold = 75.0,
    )

    println(report)

    println(maxOf(listOf(3, 7, 2, 9)))
    println(maxOf(listOf("apple", "banana", "kiwi")))
    println(maxOf(emptyList<Int>()))
}
