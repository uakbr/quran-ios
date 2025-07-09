//
//  MD5Calculator.swift
//
//
//  Created by Afifi, Mohamed on 8/16/20.
//

import CryptoKit
import Foundation

struct MD5Calculator {
    func dataMD5(for url: URL) throws -> Data {
        let bufferSize = 1024 * 1024

        // Open file for reading:
        let file = try FileHandle(forReadingFrom: url)
        defer { file.closeFile() }

        // Create MD5 hasher:
        var hasher = Insecure.MD5()

        // Read up to `bufferSize` bytes, until EOF is reached, and update MD5 hasher:
        while autoreleasepool(invoking: {
            let data = file.readData(ofLength: bufferSize)
            if !data.isEmpty {
                hasher.update(data: data)
                return true // Continue
            } else {
                return false // End of file
            }
        }) { }

        // Compute the MD5 digest:
        let digest = hasher.finalize()
        return Data(digest)
    }

    func stringMD5(for url: URL) throws -> String {
        let data = try dataMD5(for: url)
        let hex = data.map { String(format: "%02hhx", $0) }.joined()
        return hex
    }
}
