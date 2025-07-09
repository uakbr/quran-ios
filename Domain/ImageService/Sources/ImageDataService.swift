//
//  ImageDataService.swift
//
//
//  Created by Mohamed Afifi on 2021-12-15.
//

import QuranGeometry
import QuranKit
import UIKit
import VLogging
import WordFramePersistence
import WordFrameService
import Caching

public enum ImageDataServiceError: Error, LocalizedError {
    case imageNotFound(page: Page, path: String)
    case imageCorrupted(page: Page, path: String)
    
    public var errorDescription: String? {
        switch self {
        case .imageNotFound(let page, let path):
            return "Image not found for page \(page.pageNumber) at path: \(path)"
        case .imageCorrupted(let page, let path):
            return "Image corrupted for page \(page.pageNumber) at path: \(path)"
        }
    }
}

public struct ImageDataService {
    // MARK: Lifecycle

    public init(ayahInfoDatabase: URL, imagesURL: URL) {
        self.imagesURL = imagesURL
        persistence = GRDBWordFramePersistence(fileURL: ayahInfoDatabase)
        
        // Configure image cache with memory limits using our custom Cache
        imageCache.countLimit = 50 // Limit to 50 cached images
        imageCache.name = "ImagePageCache"
    }

    // MARK: Public

    public func suraHeaders(_ page: Page) async throws -> [SuraHeaderLocation] {
        try await persistence.suraHeaders(page)
    }

    public func ayahNumbers(_ page: Page) async throws -> [AyahNumberLocation] {
        try await persistence.ayahNumbers(page)
    }

    public func imageForPage(_ page: Page) async throws -> ImagePage {
        // Check cache first
        let cacheKey = "page_\(page.pageNumber)_\(page.quran.rawValue)"
        if let cachedImagePage = imageCache.object(forKey: cacheKey) {
            return cachedImagePage
        }
        
        // Load on background queue for better performance
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    let imagePage = try await self.loadImagePageFromDisk(page)
                    
                    // Cache the result
                    self.imageCache.setObject(imagePage, forKey: cacheKey)
                    
                    continuation.resume(returning: imagePage)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: Internal

    func wordFrames(_ page: Page) async throws -> WordFrameCollection {
        let plainWordFrames = try await persistence.wordFrameCollectionForPage(page)
        let wordFrames = processor.processWordFrames(plainWordFrames)
        return wordFrames
    }

    // MARK: Private

    private let processor = WordFrameProcessor()
    private let persistence: WordFramePersistence
    private let imagesURL: URL
    private let imageCache = Cache<String, ImagePage>()

    private func loadImagePageFromDisk(_ page: Page) async throws -> ImagePage {
        let imageURL = imageURLForPage(page)
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            logFiles(directory: imagesURL) // <reading>/images/width/
            logFiles(directory: imagesURL.deletingLastPathComponent()) // <reading>/images/
            logFiles(directory: imagesURL.deletingLastPathComponent().deletingLastPathComponent()) // <reading>/
            logger.error("No image found for page '\(page)' at path: \(imageURL.path)")
            throw ImageDataServiceError.imageNotFound(page: page, path: imageURL.path)
        }

        // Memory-efficient image processing
        let optimizedImage = await optimizeImageForMemory(image)
        let wordFrames = try await wordFrames(page)
        
        return ImagePage(image: optimizedImage, wordFrames: wordFrames, startAyah: page.firstVerse)
    }
    
    private func optimizeImageForMemory(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            // Process on background queue to avoid blocking main thread
            DispatchQueue.global(qos: .userInitiated).async {
                // Decompress image to avoid repeated decompression during rendering
                let decompressedImage = self.decompressImage(image)
                continuation.resume(returning: decompressedImage)
            }
        }
    }
    
    private func decompressImage(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        guard let context = context else { return image }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let decompressedCGImage = context.makeImage() else { return image }
        
        return UIImage(cgImage: decompressedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func logFiles(directory: URL) {
        let fileManager = FileManager.default
        let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let fileNames = files.map(\.lastPathComponent)
        logger.error("Images: Directory \(directory) contains files \(fileNames)")
    }

    private func imageURLForPage(_ page: Page) -> URL {
        imagesURL.appendingPathComponent("page\(page.pageNumber.as3DigitString()).png")
    }
}
