package com.example.assignment5

interface Logger {
    fun log(message: String)
}

class ConsoleLogger : Logger {
    override fun log(message: String) {
        println(message)
    }
}

class FileLogger : Logger {
    override fun log(message: String) {
        println("File: $message")
    }
}

open class Component(open val name: String)

data class LogEntry(val source: String, val event: LogEvent)

data class LogSummary(
    val infoCount: Int = 0,
    val errorCount: Int = 0,
    val debugCount: Int = 0,
    val totalCharacters: Int = 0,
)

sealed class LogEvent {
    data class Info(val message: String) : LogEvent()
    data class Error(val message: String) : LogEvent()
    data class Debug(val message: String) : LogEvent()
}

class Application(
    override val name: String = "App",
    private val logger: Logger,
) : Component(name), Logger by logger

infix fun String.taggedWith(tag: String): String = "[$tag] $this"

fun LogEvent.label(): String = when (this) {
    is LogEvent.Info -> "INFO"
    is LogEvent.Error -> "ERROR"
    is LogEvent.Debug -> "DEBUG"
}

fun LogEvent.body(): String = when (this) {
    is LogEvent.Info -> message
    is LogEvent.Error -> message
    is LogEvent.Debug -> message
}

fun LogEntry.format(
    includeSource: Boolean = true,
    prefix: String = "",
): String {
    val taggedMessage = event.body() taggedWith event.label()
    val sourcePart = if (includeSource) "${source}: " else ""
    return if (prefix.isBlank()) {
        "$sourcePart$taggedMessage"
    } else {
        "$prefix$sourcePart$taggedMessage"
    }
}

fun LogSummary.format(): String =
    "Summary: info=$infoCount, error=$errorCount, debug=$debugCount, chars=$totalCharacters"

fun logEntries(vararg entries: LogEntry): List<LogEntry> = entries.toList()

fun Logger.logAll(vararg messages: String) {
    messages.forEach { log(it) }
}

fun List<LogEntry>.formatLines(
    transform: (LogEntry) -> String,
    separator: String = "\n",
): String = map(transform).joinToString(separator)

fun selectErrors(entries: List<LogEntry>): List<LogEntry> =
    entries.filter { it.event is LogEvent.Error }

fun summarizeEntries(entries: List<LogEntry>): LogSummary =
    entries.fold(LogSummary()) { summary, entry ->
        val nextTotal = summary.totalCharacters + entry.event.body().length

        when (entry.event) {
            is LogEvent.Info -> summary.copy(
                infoCount = summary.infoCount + 1,
                totalCharacters = nextTotal,
            )
            is LogEvent.Error -> summary.copy(
                errorCount = summary.errorCount + 1,
                totalCharacters = nextTotal,
            )
            is LogEvent.Debug -> summary.copy(
                debugCount = summary.debugCount + 1,
                totalCharacters = nextTotal,
            )
        }
    }

fun buildSummary(entries: List<LogEntry>): String = summarizeEntries(entries).format()

fun main() {
    val app = Application(logger = ConsoleLogger())
    app.log("App started")

    val fileApp = Application(logger = FileLogger())
    fileApp.log("Error occurred")

    val entries = logEntries(
        LogEntry("ConsoleApp", LogEvent.Info("App started")),
        LogEntry("ConsoleApp", LogEvent.Error("Error occurred")),
        LogEntry("FileApp", LogEvent.Debug("Verbose mode enabled")),
    )

    val importantEntries = selectErrors(entries)
    val header = "Log Report" taggedWith "SYSTEM"
    val formattedLines = entries.formatLines(
        transform = { entry -> entry.format(prefix = ">> ") },
    )
    val summary = buildSummary(entries)
    val errorLine = importantEntries
        .formatLines(transform = { entry -> entry.format(includeSource = false) })
        .ifBlank { "No errors found." }

    app.logAll(
        header,
        formattedLines,
        summary,
        "Errors: $errorLine",
    )
}
