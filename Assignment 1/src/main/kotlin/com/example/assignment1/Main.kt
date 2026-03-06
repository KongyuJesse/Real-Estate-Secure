package com.example.assignment1

fun processList(
    numbers: List<Int>,
    predicate: (Int) -> Boolean,
): List<Int> {
    val filteredNumbers = mutableListOf<Int>()

    for (number in numbers) {
        if (predicate(number)) {
            filteredNumbers += number
        }
    }

    return filteredNumbers
}

fun main() {
    val nums = listOf(1, 2, 3, 4, 5, 6)
    val even = processList(nums) { it % 2 == 0 }
    val greaterThanThree = processList(nums) { it > 3 }
    val odd = processList(nums) { it % 2 != 0 }

    println("Input numbers: $nums")
    println("Even numbers: $even")
    println("Numbers greater than 3: $greaterThanThree")
    println("Odd numbers: $odd")
}
