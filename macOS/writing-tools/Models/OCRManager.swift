import Vision
import AppKit

class OCRManager {
    static let shared = OCRManager()
    
    // Given image data (from pasteboard or file upload), run OCR and return any recognized text.
    func performOCR(on imageData: Data) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    guard let nsImage = NSImage(data: imageData) else {
                        throw NSError(domain: "OCRManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
                    }
                    // Convert NSImage to CGImage
                    var cgImage: CGImage? = nil
                    for rep in nsImage.representations {
                        if let bitmapRep = rep as? NSBitmapImageRep, let cgImg = bitmapRep.cgImage {
                            cgImage = cgImg
                            break
                        }
                    }
                    guard let cgImg = cgImage else {
                        throw NSError(domain: "OCRManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot convert NSImage to CGImage"])
                    }
                    
                    let requestHandler = VNImageRequestHandler(cgImage: cgImg, options: [:])
                    let request = VNRecognizeTextRequest { request, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            let observations = request.results as? [VNRecognizedTextObservation] ?? []
                            let recognizedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                            continuation.resume(returning: recognizedText)
                        }
                    }
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    try requestHandler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
