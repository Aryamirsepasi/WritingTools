import Vision
import AppKit
import PDFKit

class OCRManager: @unchecked Sendable {
    static let shared = OCRManager()
    
    // Configuration options for OCR
    private let recognitionLanguages = [
        "en-US",    // English (US)
        "en-GB",    // English (UK)
        "de-DE",    // German
        "fr-FR",    // French
        "es-ES",    // Spanish
        "ru-RU"     // Russian
    ]
    private let dpi: CGFloat = 300
    private let recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    
    func performOCR(on imageData: Data) async throws -> String {
        guard let nsImage = NSImage(data: imageData) else {
            throw NSError(domain: "OCRManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        
        // Convert NSImage to CGImage
        guard
            let tiffData = nsImage.tiffRepresentation,
            let bitmapRep = NSBitmapImageRep(data: tiffData),
            let cgImage = bitmapRep.cgImage
        else {
            throw NSError(
                domain: "OCRManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Cannot convert NSImage to CGImage"]
            )
        }
        
        // Process the image with the same optimized settings as PDF OCR
        return try await processImageFromCGImage(cgImage)
    }
    
    func performOCR(onPDF pdfData: Data) async throws -> String {
        guard let pdfDocument = PDFDocument(data: pdfData) else {
            throw NSError(domain: "OCRManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid PDF data"])
        }

        var allText = ""
        let pageCount = pdfDocument.pageCount

        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            // Convert PDF page to high-quality image
            guard let cgImage = try await renderPDFPageToImage(page) else { continue }
            
            // Process OCR on the image
            let pageText = try await processImageFromCGImage(cgImage)
            
            // Only add non-empty text with page markers
            if !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !allText.isEmpty {
                    allText += "\n\n"
                }
                allText += "Page \(pageIndex + 1):\n\(pageText)"
            }
        }

        return allText
    }
    
    private func renderPDFPageToImage(_ page: PDFPage) async throws -> CGImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let scale = dpi / 72.0  // Convert from PDF points (72 DPI) to desired DPI
        
        // Calculate dimensions
        let pixelWidth = Int(pageRect.width * scale)
        let pixelHeight = Int(pageRect.height * scale)
        
        // Create bitmap context with optimal settings for OCR
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }
        
        // Set up high-quality rendering
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setAllowsFontSmoothing(true)
        context.setShouldSmoothFonts(true)
        context.interpolationQuality = .high
        
        // Fill background with white for better contrast
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        
        // Set up transform
        context.translateBy(x: 0, y: CGFloat(pixelHeight))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -pageRect.origin.x, y: -pageRect.origin.y)
        
        // Draw PDF page
        page.draw(with: .mediaBox, to: context)
        
        return context.makeImage()
    }

    private func processImageFromCGImage(_ cgImage: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedText = observations.compactMap { observation -> String? in
                    // Get top 3 candidates and choose the most confident one
                    let candidates = observation.topCandidates(3)
                    guard let bestCandidate = candidates.first else { return nil }
                    
                    // Filter out low confidence results
                    if bestCandidate.confidence < 0.4 {
                        return nil
                    }
                    
                    return bestCandidate.string
                }
                .joined(separator: " ")
                
                continuation.resume(returning: recognizedText)
            }
            
            // Configure the request for optimal results
            request.recognitionLevel = recognitionLevel
            request.usesLanguageCorrection = true
            request.recognitionLanguages = recognitionLanguages
            request.minimumTextHeight = 0.01 // Relative to image height
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // Helper to detect if the data is a PDF
    func isPDF(data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        let pdfHeader = "%PDF"
        return String(data: data.prefix(4), encoding: .ascii) == pdfHeader
    }
}
