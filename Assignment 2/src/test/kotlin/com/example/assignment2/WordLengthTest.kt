package com.example.assignment2

import kotlin.test.Test
import kotlin.test.assertEquals

class WordLengthTest {
    @Test
    fun `builds a map of words to their lengths`() {
        val words = listOf("apple", "cat", "banana", "dog", "elephant")

        val result = buildWordLengthMap(words)

        assertEquals(
            linkedMapOf(
                "apple" to 5,
                "cat" to 3,
                "banana" to 6,
                "dog" to 3,
                "elephant" to 8,
            ),
            result,
        )
    }

    @Test
    fun `keeps only entries longer than four characters`() {
        val wordLengths = linkedMapOf(
            "apple" to 5,
            "cat" to 3,
            "banana" to 6,
            "dog" to 3,
            "elephant" to 8,
        )

        val result = filterWordsLongerThan(wordLengths)

        assertEquals(
            linkedMapOf(
                "apple" to 5,
                "banana" to 6,
                "elephant" to 8,
            ),
            result,
        )
    }

    @Test
    fun `formats each printed line consistently`() {
        assertEquals("banana has length 6", formatWordLengthEntry("banana", 6))
    }

    @Test
    fun `returns an empty map for empty input`() {
        val result = buildWordLengthMap(emptyList())

        assertEquals(emptyMap(), result)
    }
}

