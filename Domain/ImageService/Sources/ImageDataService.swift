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

public enum ImageDataServiceError: Error {
    case imageNotFound(page: Page, path: String)
    case imageCorrupted(page: Page, path: String)
    case processingFailed(page: Page, error: Error)
}

public struct ImageDataService: Sendable {
    // MARK: Lifecycle

    public init(ayahInfoDatabase: URL, imagesURL: URL) {
        self.imagesURL = imagesURL
        persistence = GRDBWordFramePersistence(fileURL: ayahInfoDatabase)
        
        // Configure image cache with memory limits using our custom Cache
        imageCache = Cache<NSNumber, ImagePage>()
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

    public func image(for page: Page) async throws -> ImagePage {
        // Check cache first
        if let cachedImage = await imageCache.object(forKey: page.pageIndex as NSNumber) {
            return cachedImage
        }
        
        // Load image on background thread
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    let pageNumber = page.pageIndex  // Extract value to avoid capture
                    let imageName = "page\(String(format: "%03d", pageNumber))"
                    let imageURL = self.imagesURL.appendingPathComponent("\(imageName).png")
                    
                    guard FileManager.default.fileExists(atPath: imageURL.path) else {
                        throw ImageDataServiceError.imageNotFound(page: page, path: imageURL.path)
                    }
                    
                    guard let uiImage = UIImage(contentsOfFile: imageURL.path) else {
                        throw ImageDataServiceError.imageCorrupted(page: page, path: imageURL.path)
                    }
                    
                    // Decompress image on background thread
                    let decompressedImage = await self.decompressImage(uiImage)
                    let imagePage = ImagePage(page: page, image: decompressedImage)
                    
                    // Cache the result
                    await self.imageCache.setObject(imagePage, forKey: pageNumber as NSNumber)
                    
                    continuation.resume(returning: imagePage)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: Private

    private let persistence: WordFramePersistence
    private let imagesURL: URL
    private let imageCache: Cache<NSNumber, ImagePage>

    private func decompressImage(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            Task.detached {
                guard let cgImage = image.cgImage else { 
                    continuation.resume(returning: image)
                    return
                }
                
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
                
                guard let context = context else { 
                    continuation.resume(returning: image)
                    return
                }
                
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
                
                guard let decompressedCGImage = context.makeImage() else {
                    continuation.resume(returning: image)
                    return
                }
                
                let decompressedImage = UIImage(cgImage: decompressedCGImage)
                continuation.resume(returning: decompressedImage)
            }
        }
    }
}
