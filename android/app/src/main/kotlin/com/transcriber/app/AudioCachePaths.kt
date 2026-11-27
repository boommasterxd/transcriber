package com.transcriber.app

import java.io.File
import java.io.IOException
import java.nio.file.Files

/** Validates managed cache roots and filenames before any cache operation. */
internal class AudioCachePaths(private val cacheDirectory: File) {
    fun files(): List<File> = roots.flatMap(::listFiles)

    fun sharedDirectory(): File? = root(sharedRoot)?.takeIf {
        (it.exists() || it.mkdirs()) && it.isDirectory
    }

    fun managedFile(file: File, recordingOnly: Boolean = false): File? {
        val parent = file.absoluteFile.parentFile
        val canonicalCache = cacheDirectory.canonicalFile
        val candidates = if (recordingOnly) listOf(recordingRoot) else roots
        val kind = candidates.firstOrNull {
            parent == File(cacheDirectory.absoluteFile, it.directory) || parent == File(canonicalCache, it.directory)
        } ?: return null
        return root(kind)?.let { File(it, file.name).takeIf { leaf -> isManagedLeaf(leaf, kind) } }
    }

    private fun listFiles(kind: Root): List<File> {
        val directory = root(kind)?.takeIf { it.exists() } ?: return emptyList()
        return directory.listFiles { file -> isManagedLeaf(file, kind) && file.isFile }?.toList()
            ?: throw IOException("Unable to inspect the audio cache")
    }

    private fun root(kind: Root): File? {
        val directory = File(cacheDirectory.canonicalFile, kind.directory)
        val safe = isCanonical(directory) && directory.parentFile?.let { !Files.isSymbolicLink(it.toPath()) } == true
        return directory.takeIf { safe && (!it.exists() || it.isDirectory) }
    }

    private fun isManagedLeaf(file: File, kind: Root): Boolean =
        kind.namePattern.matches(file.name) && isCanonical(file)

    private data class Root(val directory: String, val namePattern: Regex)

    companion object {
        private const val stamp = "-?[0-9]+_[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}"
        private const val audioExtension = "\\.(?:flac|mp3|mp4|mpeg|mpga|m4a|ogg|opus|wav|webm)"
        private val sharedRoot = Root("shared", Regex("${stamp}_.+$audioExtension", RegexOption.IGNORE_CASE))
        private val recordingRoot = Root("audio/recording", Regex("recording_$stamp\\.wav", RegexOption.IGNORE_CASE))
        private val roots = listOf(
            sharedRoot,
            Root("audio/import", Regex("$stamp$audioExtension", RegexOption.IGNORE_CASE)),
            recordingRoot,
        )

        fun delete(file: File): Boolean = isCanonical(file) && (!file.exists() || file.delete())

        private fun isCanonical(file: File): Boolean =
            file.canonicalFile == file && !Files.isSymbolicLink(file.toPath())
    }
}
