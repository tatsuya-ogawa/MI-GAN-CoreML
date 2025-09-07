# MI-GAN CoreML iOS App

This project converts the [MI-GAN (Mask-based Image Inpainting with Generative Adversarial Networks)](https://github.com/Picsart-AI-Research/MI-GAN) PyTorch models to CoreML format and provides an iOS application for real-time image inpainting on mobile devices.

## Overview

MI-GAN is a state-of-the-art deep learning model for image inpainting that can fill missing or masked regions in images with semantically coherent content. This project enables you to run MI-GAN inference directly on iOS devices using Apple's CoreML framework.

## Features

- **PyTorch to CoreML Conversion**: Convert pre-trained MI-GAN models to CoreML format
- **iOS Native App**: SwiftUI-based iOS application for image inpainting
- **Real-time Inference**: On-device inference with no internet connection required
- **Multiple Model Support**: Support for both 256x256 and 512x512 resolution models
- **Mask Inversion**: Toggle between white-hole and black-hole mask modes
- **Interactive UI**: Easy-to-use interface with image selection and result display

## Model Conversion

### Prerequisites
- Python 3.8+
- PyTorch
- CoreMLTools
- Original MI-GAN pre-trained models (.pt files)

### Conversion Scripts

Convert MI-GAN PyTorch models to CoreML format using the provided export script:

```bash
# Convert 256x256 model
./export.sh -m migan_256_places2.pt -o migan_256_coreml.mlpackage -r 256

# Convert 512x512 model  
./export.sh -m migan_512_places2.pt -o migan_512_coreml.mlpackage -r 512
```

### Script Parameters
- `-m`: Path to the input PyTorch model file (.pt)
- `-o`: Output CoreML model package name (.mlpackage)
- `-r`: Model resolution (256 or 512)

## iOS Application

### Requirements
- iOS 14.0+
- Xcode 13.0+
- Swift 5.0+

### Key Features

#### Model Integration
- Automatic CoreML model loading
- Optimized preprocessing matching the original Python implementation
- Proper tensor format conversion (CHW format, [-1,1] normalization)

#### Image Processing Pipeline
1. **Input Preprocessing**: 
   - Resize images to model resolution (256x256 or 512x512)
   - Normalize RGB values to [-1, 1] range
   - Apply mask preprocessing with optional inversion
   - Combine input as `[mask - 0.5, img * mask]` tensor format

2. **Model Inference**: 
   - Run CoreML prediction on device
   - Handle output tensor in CHW format

3. **Output Postprocessing**:
   - Convert output from [-1, 1] to [0, 1] range using `* 0.5 + 0.5`
   - Convert to UIImage for display

#### User Interface
- **Split View Design**: Controls on the left sidebar, results on the main content area
- **Image Selection**: Photo picker for input images and masks
- **Mask Inversion Toggle**: Switch between white-hole and black-hole mask modes
- **Demo Mode**: Built-in demo images for quick testing
- **Save Functionality**: Save results to Photos app

### Usage
1. Load the iOS project in Xcode
2. Place your converted `.mlpackage` file in the project
3. Update the model name in `InPaintingManager.swift`
4. Build and run on device or simulator
5. Select input image and mask, then tap "Perform Inpainting"

## Technical Implementation

### Model Architecture
- Based on MI-GAN architecture with encoder-decoder structure
- Input: 4-channel tensor (3 RGB + 1 mask channel)
- Output: 3-channel RGB tensor
- Supports multiple resolutions (256x256, 512x512)

### Performance Optimization
- CoreML optimization for iOS hardware acceleration
- Efficient memory management for large images
- Asynchronous processing to maintain UI responsiveness

## Project Structure

```
MI-GAN-CoreML/
├── MI-GAN/                    # Original MI-GAN implementation
├── iOS-InPainting/            # iOS application
│   ├── InPaintingManager.swift # CoreML integration
│   └── ContentView.swift      # SwiftUI interface
├── export.sh                  # Model conversion script
├── exec.sh                    # Batch conversion script
└── README.md
```

## License

This project is based on the original MI-GAN research. Please refer to the original [MI-GAN repository](https://github.com/Picsart-AI-Research/MI-GAN) for license details.

## Acknowledgments

- Original MI-GAN paper and implementation by Picsart AI Research
- Apple CoreML framework for on-device inference
- SwiftUI for modern iOS interface development