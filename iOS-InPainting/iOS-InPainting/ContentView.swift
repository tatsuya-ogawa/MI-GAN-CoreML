//
//  ContentView.swift
//  iOS-InPainting
//
//  Created by Tatsuya Ogawa on 2025/09/07.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var inPaintingManager = InPaintingManager()
    @State private var inputImage: UIImage?
    @State private var maskImage: UIImage?
    @State private var resultImage: UIImage?
    @State private var showingInputImagePicker = false
    @State private var showingMaskImagePicker = false
    @State private var inputItem: PhotosPickerItem?
    @State private var maskItem: PhotosPickerItem?
    @State private var invertMask = false
    
    var body: some View {
        NavigationView {
            // Side Menu (Left side)
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack {
                        Text("MI-GAN Inpainting")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Select input image and mask to perform inpainting")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Demo Button
                        Button(action: loadDemoImages) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Try Demo")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    
                    // Demo Info (show when demo images are loaded)
                    if inputImage != nil && maskImage != nil {
                        VStack {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Demo images loaded! Tap 'Perform Inpainting' to see MI-GAN in action.")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    
                    // Input Section
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("1. Input Image")
                                .font(.headline)
                            Spacer()
                            if inputImage != nil && UIImage(named: "input") == inputImage {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Demo")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        PhotosPicker(selection: $inputItem, matching: .images) {
                            if let inputImage = inputImage {
                                Image(uiImage: inputImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue, lineWidth: 2)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 150)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.largeTitle)
                                                .foregroundColor(.blue)
                                            Text("Tap to select input image")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    )
                            }
                        }
                        .onChange(of: inputItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    inputImage = uiImage
                                }
                            }
                        }
                    }
                    
                    // Mask Section
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("2. Mask Image")
                                .font(.headline)
                            Spacer()
                            if maskImage != nil && UIImage(named: "mask") == maskImage {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Demo")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        PhotosPicker(selection: $maskItem, matching: .images) {
                            if let maskImage = maskImage {
                                Image(uiImage: maskImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.green, lineWidth: 2)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 150)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.largeTitle)
                                                .foregroundColor(.green)
                                            Text("Tap to select mask image")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    )
                            }
                        }
                        .onChange(of: maskItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    maskImage = uiImage
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Toggle("Invert Mask", isOn: $invertMask)
                                    .font(.caption)
                            }
                            
                            Text(invertMask ? "Black areas in the mask will be inpainted" : "White areas in the mask will be inpainted")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Process Button
                    Button(action: processInPainting) {
                        HStack {
                            if inPaintingManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "wand.and.rays")
                            }
                            Text(inPaintingManager.isLoading ? "Processing..." : "Perform Inpainting")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProcess ? Color.blue : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(!canProcess || inPaintingManager.isLoading)
                    
                    // Error Message
                    if let errorMessage = inPaintingManager.errorMessage {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
            }
            .navigationTitle("Controls")
            .navigationBarTitleDisplayMode(.inline)
            
            // Main Content (Right side)
            VStack {
                if let resultImage = resultImage {
                    VStack(spacing: 20) {
                        HStack {
                            Text("Result")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Spacer()
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Generated")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        
                        Image(uiImage: resultImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.orange, lineWidth: 3)
                            )
                            .shadow(radius: 10)
                            .onAppear {
                                print("🖼️ Result image is being displayed in main content")
                            }
                        
                        Button(action: saveResult) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save to Photos")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: 300)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.bottom)
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    VStack {
                        Spacer()
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 100))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Result will appear here")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("MI-GAN Inpainting")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var canProcess: Bool {
        inputImage != nil && maskImage != nil
    }
    
    private func processInPainting() {
        guard let inputImage = inputImage, let maskImage = maskImage else { 
            print("❌ Input or mask image is nil")
            return 
        }
        
        print("🎬 Processing inpainting...")
        resultImage = nil
        inPaintingManager.performInPainting(inputImage: inputImage, maskImage: maskImage, invertMask: invertMask) { result in
            print("📱 Received result in ContentView: \(result != nil ? "Success" : "Failed")")
            Task { @MainActor in
                self.resultImage = result
                print("🔄 UI updated with result image")
            }
        }
    }
    
    private func saveResult() {
        guard let resultImage = resultImage else { return }
        UIImageWriteToSavedPhotosAlbum(resultImage, nil, nil, nil)
    }
    
    private func loadDemoImages() {
        // Load demo input image
        if let demoInputImage = UIImage(named: "input") {
            inputImage = demoInputImage
        }
        
        // Load demo mask image
        if let demoMaskImage = UIImage(named: "mask") {
            maskImage = demoMaskImage
        }
        
        // Clear previous result
        resultImage = nil
    }
}

#Preview {
    ContentView()
}
