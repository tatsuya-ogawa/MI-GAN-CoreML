# MI-GAN Inpainting iOS App

This iOS app demonstrates image inpainting using the MI-GAN (Mask-Image Guided Attention Network) model converted to CoreML.

## Features

- **Image Selection**: Choose input images from your photo library
- **Mask Creation**: Select or create masks to define areas to inpaint
- **AI Inpainting**: Uses MI-GAN 512x512 model for high-quality results
- **Results Saving**: Save processed images back to your photo library

## How to Use

1. **Select Input Image**: Tap on the input image section and choose an image from your photo library
2. **Select Mask Image**: Tap on the mask image section and choose a mask image
   - White areas in the mask will be inpainted
   - Black areas will remain unchanged
3. **Process**: Tap "Perform Inpainting" to run the MI-GAN model
4. **Save**: Once processing is complete, save the result to your photos

## Sample Images

The app includes sample images in the project:
- `input.png`: Sample input image
- `mask.png`: Sample mask image

## Technical Details

- **Model**: MI-GAN 512x512 resolution
- **Framework**: SwiftUI + CoreML
- **Input**: 4-channel image (RGB + mask)
- **Output**: 3-channel RGB inpainted image
- **Processing Time**: Varies based on device (typically 2-10 seconds)

## Requirements

- iOS 16.0+
- Compatible with iPhone and iPad
- Requires photo library access permissions

## Model Information

The CoreML model (`migan_512_coreml.mlpackage`) was converted from the original MI-GAN PyTorch implementation and optimized for mobile inference.