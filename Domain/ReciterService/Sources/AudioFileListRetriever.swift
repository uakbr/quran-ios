//
//  AudioFileListRetriever.swift
//  Quran
//
//  Created by Mohamed Afifi on 4/17/17.
//

import Foundation
import QuranAudio
import QuranKit
import Utilities
import VLogging

public enum AudioFileListRetrieverError: Error, LocalizedError {
    case unsupportedReciterType(reciter: Reciter, expected: AudioType, actual: AudioType, operation: String)
    case missingDatabaseConfiguration(reciter: Reciter)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedReciterType(let reciter, let expected, let actual, let operation):
            return "Unsupported reciter type for \(operation). Reciter '\(reciter.localizedName)' has type '\(actual)' but expected '\(expected)'"
        case .missingDatabaseConfiguration(let reciter):
            return "Missing database configuration for reciter: \(reciter.localizedName)"
        }
    }
}

public struct ReciterAudioFile: Sendable, Hashable {
    public var remote: URL
    public var local: RelativeFilePath
    public var sura: Sura? = nil
}

private protocol AudioFileListRetriever {
    func get(for reciter: Reciter, from start: AyahNumber, to end: AyahNumber) throws -> [ReciterAudioFile]
}

private struct GaplessAudioFileListRetriever: AudioFileListRetriever {
    let baseURL: URL

    func get(for reciter: Reciter, from start: AyahNumber, to end: AyahNumber) throws -> [ReciterAudioFile] {
        guard case AudioType.gapless(databaseName: _) = reciter.audioType else {
            logger.error("Unsupported reciter type for gapless audio file retrieval. Reciter: \(reciter.localizedName), Type: \(reciter.audioType)")
            throw AudioFileListRetrieverError.unsupportedReciterType(
                reciter: reciter,
                expected: .gapless(databaseName: ""),
                actual: reciter.audioType,
                operation: "gapless audio file retrieval"
            )
        }
        
        guard let databaseRemoteURL = reciter.databaseRemoteURL(baseURL: baseURL),
              let localDatabasePath = reciter.localZipPath
        else {
            logger.error("Missing database configuration for gapless reciter: \(reciter.localizedName)")
            throw AudioFileListRetrieverError.missingDatabaseConfiguration(reciter: reciter)
        }

        let dbFile = ReciterAudioFile(remote: databaseRemoteURL, local: localDatabasePath)

        // loop over the files
        var files = Set<ReciterAudioFile>()

        for sura in start.sura.array(to: end.sura) {
            let remoteURL = reciter.remoteURL(sura: sura)
            let localPath = reciter.localURL(sura: sura)
            files.insert(ReciterAudioFile(remote: remoteURL, local: localPath, sura: sura))
        }
        return Array(files) + [dbFile]
    }
}

private struct GappedAudioFileListRetriever: AudioFileListRetriever {
    // MARK: Internal

    func get(for reciter: Reciter, from start: AyahNumber, to end: AyahNumber) throws -> [ReciterAudioFile] {
        guard case AudioType.gapped = reciter.audioType else {
            logger.error("Unsupported reciter type for gapped audio file retrieval. Reciter: \(reciter.localizedName), Type: \(reciter.audioType)")
            throw AudioFileListRetrieverError.unsupportedReciterType(
                reciter: reciter,
                expected: .gapped,
                actual: reciter.audioType,
                operation: "gapped audio file retrieval"
            )
        }

        var files = Set<ReciterAudioFile>()

        // add besm Allah for all gapped audio
        files.insert(createRequestInfo(reciter: reciter, ayah: start.quran.firstVerse))

        for ayah in start.array(to: end) {
            files.insert(createRequestInfo(reciter: reciter, ayah: ayah))
        }
        return Array(files)
    }

    // MARK: Private

    private func createRequestInfo(reciter: Reciter, ayah: AyahNumber) -> ReciterAudioFile {
        let remoteURL = reciter.remoteURL(ayah: ayah)
        let localURL = reciter.localURL(ayah: ayah)
        return ReciterAudioFile(remote: remoteURL, local: localURL, sura: ayah.sura)
    }
}

extension Reciter {
    public func audioFiles(baseURL: URL, from: AyahNumber, to: AyahNumber) throws -> [ReciterAudioFile] {
        let retriever = retriever(baseURL: baseURL)
        return try retriever.get(for: self, from: from, to: to)
    }

    private func retriever(baseURL: URL) -> AudioFileListRetriever {
        switch audioType {
        case .gapped: return GappedAudioFileListRetriever()
        case .gapless: return GaplessAudioFileListRetriever(baseURL: baseURL)
        }
    }
}
