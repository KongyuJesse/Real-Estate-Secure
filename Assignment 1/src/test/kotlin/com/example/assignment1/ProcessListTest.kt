package com.example.assignment1

import kotlin.test.Test
import kotlin.test.assertEquals

class ProcessListTest {
    @Test
    fun `returns only even numbers`() {
        val nums = listOf(1, 2, 3, 4, 5, 6)

        val even = processList(nums) { it % 2 == 0 }

        assertEquals(listOf(2, 4, 6), even)
    }

    @Test
    fun `returns numbers greater than three`() {
        val nums = listOf(1, 2, 3, 4, 5, 6)

        val result = processList(nums) { it > 3 }

        assertEquals(listOf(4, 5, 6), result)
    }

    @Test
    fun `returns empty list when input is empty`() {
        val result = processList(emptyList()) { it % 2 == 0 }

        assertEquals(emptyList(), result)
    }

    @Test
    fun `returns empty list when no items match`() {
        val nums = listOf(1, 3, 5, 7)

        val result = processList(nums) { it % 2 == 0 }

        assertEquals(emptyList(), result)
    }
}

