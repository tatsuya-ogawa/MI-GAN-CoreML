//
//  InPaintingManager.swift
//  iOS-InPainting
//
//  Created by Tatsuya Ogawa on 2025/09/07.
//

import CoreML
import Vision
import UIKit
import CoreImage

class InPaintingManager: ObservableObject {
    private var model: migan_512_coreml?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        loadModel()
    }
    
    private func loadModel() {
        do {
            model = try migan_512_coreml()
        } catch {
            errorMessage = "Failed to load model: \(error.localizedDescription)"
        }
    }
    
    func performInPainting(inputImage: UIImage, maskImage: UIImage, invertMask: Bool = false, completion: @escaping (UIImage?) -> Void) {
        guard let model = model else {
            print("❌ Model is nil")
            errorMessage = "Model not loaded"
            completion(nil)
            return
        }
        
        print("🚀 Starting inpainting process...")
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                // Resize images to 512x512
                print("📐 Resizing images to 512x512...")
                let resizedInput = self?.resizeImage(inputImage, to: CGSize(width: 512, height: 512))
                let resizedMask = self?.resizeImage(maskImage, to: CGSize(width: 512, height: 512))
                
                guard let inputImage = resizedInput, let maskImage = resizedMask else {
                    print("❌ Failed to resize images")
                    Task { @MainActor in
                        self?.isLoading = false
                        self?.errorMessage = "Failed to resize images"
                        completion(nil)
                    }
                    return
                }
                
                print("🔄 Converting to MLMultiArray...")
                // Convert to 4-channel MLMultiArray (RGB + mask)
                guard let combinedMultiArray = self?.createCombinedMultiArray(inputImage: inputImage, maskImage: maskImage, invertMask: invertMask) else {
                    print("❌ Failed to create MLMultiArray")
                    Task { @MainActor in
                        self?.isLoading = false
                        self?.errorMessage = "Failed to create input array"
                        completion(nil)
                    }
                    return
                }
                
                print("🤖 Running MI-GAN inference...")
                // Perform prediction using the generated model class
                let output = try model.prediction(input_image: combinedMultiArray)
                
                print("🖼️ Converting output to UIImage...")
                // Convert output MLMultiArray to UIImage
                let resultImage = self?.multiArrayToUIImage(multiArray: output.output_image)
                
                if let resultImage = resultImage {
                    print("✅ Successfully created result image")
                } else {
                    print("❌ Failed to convert MLMultiArray to UIImage")
                }
                
                Task { @MainActor in
                    self?.isLoading = false
                    completion(resultImage)
                    print("🔄 InPaintingManager: Completed on main thread")
                }
                
            } catch {
                Task { @MainActor in
                    self?.isLoading = false
                    self?.errorMessage = "Inference failed: \(error.localizedDescription)"
                    completion(nil)
                    print("🔄 InPaintingManager: Error handled on main thread")
                }
            }
        }
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func createCombinedMultiArray(inputImage: UIImage, maskImage: UIImage, invertMask: Bool) -> MLMultiArray? {
        let width = 512
        let height = 512
        let channels = 4
        
        guard let multiArray = try? MLMultiArray(shape: [1, NSNumber(value: channels), NSNumber(value: height), NSNumber(value: width)], dataType: .float32) else {
            return nil
        }
        
        // Convert UIImages to pixel data
        guard let inputCGImage = inputImage.cgImage,
              let maskCGImage = maskImage.cgImage else {
            return nil
        }
        
        // Create contexts for image processing
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        // Process input image (RGB)
        var inputPixelData = Data(count: width * height * bytesPerPixel)
        inputPixelData.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress,
                                        width: width,
                                        height: height,
                                        bitsPerComponent: 8,
                                        bytesPerRow: bytesPerRow,
                                        space: colorSpace,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return
            }
            context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        // Process mask image
        var maskPixelData = Data(count: width * height * bytesPerPixel)
        maskPixelData.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress,
                                        width: width,
                                        height: height,
                                        bitsPerComponent: 8,
                                        bytesPerRow: bytesPerRow,
                                        space: colorSpace,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return
            }
            context.draw(maskCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        // Fill MLMultiArray with normalized pixel values
        let inputBytes = inputPixelData.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        let maskBytes = maskPixelData.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let byteIndex = pixelIndex * 4
                
                // Normalize mask to [0,1] first, then invert if needed
                var maskValue = Float(maskBytes[byteIndex]) / 255.0
                if invertMask {
                    maskValue = 1.0 - maskValue
                }
                
                // Normalize image to [-1,1] (same as Python: * 2 / 255 - 1)
                let imgR = Float(inputBytes[byteIndex]) * 2.0 / 255.0 - 1.0
                let imgG = Float(inputBytes[byteIndex + 1]) * 2.0 / 255.0 - 1.0
                let imgB = Float(inputBytes[byteIndex + 2]) * 2.0 / 255.0 - 1.0
                
                // Follow Python logic: x = torch.cat([mask - 0.5, img * mask], dim=1)
                // Channel 0: mask - 0.5
                multiArray[[0, 0, NSNumber(value: y), NSNumber(value: x)]] = NSNumber(value: maskValue - 0.5)
                
                // Channels 1-3: img * mask (RGB channels multiplied by mask)
                multiArray[[0, 1, NSNumber(value: y), NSNumber(value: x)]] = NSNumber(value: imgR * maskValue) // R * mask
                multiArray[[0, 2, NSNumber(value: y), NSNumber(value: x)]] = NSNumber(value: imgG * maskValue) // G * mask
                multiArray[[0, 3, NSNumber(value: y), NSNumber(value: x)]] = NSNumber(value: imgB * maskValue) // B * mask
            }
        }
        
        return multiArray
    }
    
    private func multiArrayToUIImage(multiArray: MLMultiArray) -> UIImage? {
        let width = 512
        let height = 512
        
        print("🔍 MLMultiArray shape: \(multiArray.shape)")
        print("🔍 MLMultiArray dataType: \(multiArray.dataType)")
        
        // Create pixel data array
        var pixelData = Data(count: width * height * 4) // RGBA
        
        // Try to access raw data pointer for better performance
        let dataPointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: multiArray.count)
        
        pixelData.withUnsafeMutableBytes { bytes in
            let buffer = bytes.bindMemory(to: UInt8.self)
            
            for y in 0..<height {
                for x in 0..<width {
                    let pixelIndex = y * width + x
                    let byteIndex = pixelIndex * 4
                    
                    // Calculate indices for CHW format (Channel, Height, Width)
                    let rIndex = 0 * height * width + y * width + x
                    let gIndex = 1 * height * width + y * width + x  
                    let bIndex = 2 * height * width + y * width + x
                    
                    let r = dataPointer[rIndex]
                    let g = dataPointer[gIndex]
                    let b = dataPointer[bIndex]
                    
                    // Debug first few pixels
                    if pixelIndex < 3 {
                        print("🎯 Pixel \(pixelIndex) raw values: R=\(r), G=\(g), B=\(b)")
                    }
                    
                    // Convert from [-1, 1] to [0, 1] (same as Python: * 0.5 + 0.5)
                    let normalizedR = r * 0.5 + 0.5
                    let normalizedG = g * 0.5 + 0.5
                    let normalizedB = b * 0.5 + 0.5
                    
                    // Debug first few pixels after normalization
                    if pixelIndex < 3 {
                        print("🎯 Pixel \(pixelIndex) normalized values: R=\(normalizedR), G=\(normalizedG), B=\(normalizedB)")
                    }
                    
                    // Clamp to [0, 1] and convert to [0, 255]
                    buffer[byteIndex] = UInt8(max(0, min(255, normalizedR * 255)))     // R
                    buffer[byteIndex + 1] = UInt8(max(0, min(255, normalizedG * 255))) // G
                    buffer[byteIndex + 2] = UInt8(max(0, min(255, normalizedB * 255))) // B
                    buffer[byteIndex + 3] = 255                                         // A (full opacity)
                }
            }
        }
        
        // Create CGImage from pixel data
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let bytesPerRow = width * 4
        
        guard let dataProvider = CGDataProvider(data: pixelData as CFData) else {
            print("❌ Failed to create CGDataProvider")
            return nil
        }
        
        guard let cgImage = CGImage(width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 32,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo,
                                  provider: dataProvider,
                                  decode: nil,
                                  shouldInterpolate: false,
                                  intent: .defaultIntent) else {
            print("❌ Failed to create CGImage")
            return nil
        }
        
        print("✅ Successfully created UIImage from CGImage")
        return UIImage(cgImage: cgImage)
    }
    
    private func pixelBufferToUIImage(pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}
