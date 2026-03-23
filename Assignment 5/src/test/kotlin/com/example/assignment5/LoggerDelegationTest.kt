package com.example.assignment5

import kotlin.test.Test
import kotlin.test.assertEquals

class LoggerDelegationTest {
    private class RecordingLogger : Logger {
        private val _messages = mutableListOf<String>()
        val messages: List<String> = _messages

        override fun log(message: String) {
            _messages.add(message)
        }
    }

    @Test
    fun `application delegates logging to its logger`() {
        val logger = RecordingLogger()
        val app = Application(logger = logger)

        app.log("Hello!")

        assertEquals(listOf("Hello!"), logger.messages)
    }

    @Test
    fun `formats a log entry with tag and prefix`() {
        val entry = LogEntry("Auth", LogEvent.Info("Signed in"))

        val result = entry.format(prefix = ">> ")

        assertEquals(">> Auth: [INFO] Signed in", result)
    }

    @Test
    fun `filters only error entries`() {
        val entries = listOf(
            LogEntry("App", LogEvent.Info("Start")),
            LogEntry("App", LogEvent.Error("Crash")),
        )

        val result = selectErrors(entries)

        assertEquals(listOf(LogEntry("App", LogEvent.Error("Crash"))), result)
    }

    @Test
    fun `summarizeEntries counts each log level and characters`() {
        val entries = listOf(
            LogEntry("App", LogEvent.Info("Start")),
            LogEntry("App", LogEvent.Error("Fail")),
            LogEntry("App", LogEvent.Debug("Trace")),
        )

        val result = summarizeEntries(entries)

        assertEquals(
            LogSummary(
                infoCount = 1,
                errorCount = 1,
                debugCount = 1,
                totalCharacters = 14,
            ),
            result,
        )
    }

    @Test
    fun `buildSummary formats the calculated log summary`() {
        val entries = listOf(
            LogEntry("App", LogEvent.Info("Start")),
            LogEntry("App", LogEvent.Error("Fail")),
            LogEntry("App", LogEvent.Debug("Trace")),
        )

        val result = buildSummary(entries)

        assertEquals("Summary: info=1, error=1, debug=1, chars=14", result)
    }
}
