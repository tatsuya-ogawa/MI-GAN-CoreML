#!/bin/bash

# MI-GAN CoreML Export Script
# This script converts a trained MI-GAN model to CoreML format

set -e

echo "Starting MI-GAN to CoreML conversion..."

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "Error: Python3 is required but not found"
    exit 1
fi

# Default parameters
MODEL_PATH=""
OUTPUT_PATH="./migan_coreml.mlpackage"
RESOLUTION=256

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            MODEL_PATH="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_PATH="$2"
            shift 2
            ;;
        -r|--resolution)
            RESOLUTION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  -m, --model PATH       Path to the trained MI-GAN model (.pkl or .pth)"
            echo "  -o, --output PATH      Output path for CoreML model (default: ./migan_coreml.mlpackage)"
            echo "  -r, --resolution SIZE  Image resolution (default: 256)"
            echo "  -h, --help             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if model path is provided
if [[ -z "$MODEL_PATH" ]]; then
    echo "Error: Model path is required. Use -m or --model to specify."
    echo "Use -h or --help for usage information."
    exit 1
fi

# Check if model file exists
if [[ ! -f "$MODEL_PATH" ]]; then
    echo "Error: Model file not found: $MODEL_PATH"
    exit 1
fi

# Create virtual environment and install required packages
echo "Setting up virtual environment..."
python3 -m venv ./venv
source ./venv/bin/activate

echo "Installing required packages..."
pip install coremltools torch torchvision numpy requests

# Create temporary Python script for conversion
cat > /tmp/migan_to_coreml.py << 'EOF'
import sys
import torch
import numpy as np
import coremltools as ct
from pathlib import Path

def load_migan_model(model_path, resolution=256):
    """Load MI-GAN model from checkpoint"""
    import os
    # Get current working directory and add MI-GAN to path
    cwd = os.getcwd()
    migan_path = os.path.join(cwd, 'MI-GAN')
    sys.path.insert(0, migan_path)
    print(f"Adding to Python path: {migan_path}")
    
    try:
        from lib.model_zoo.migan_inference import Generator
    except ImportError as e:
        print(f"Error importing MI-GAN modules: {e}")
        print("Make sure you're running this script from the correct directory")
        sys.exit(1)
    
    # Initialize model
    model = Generator(resolution=resolution)
    
    # Load checkpoint
    if str(model_path).endswith('.pkl'):
        # StyleGAN2 format
        with open(model_path, 'rb') as f:
            import pickle
            data = pickle.load(f)
            if 'G_ema' in data:
                state_dict = data['G_ema']
            elif 'generator' in data:
                state_dict = data['generator']
            else:
                state_dict = data
    else:
        # Standard PyTorch format
        checkpoint = torch.load(model_path, map_location='cpu')
        if 'model_state_dict' in checkpoint:
            state_dict = checkpoint['model_state_dict']
        elif 'generator' in checkpoint:
            state_dict = checkpoint['generator']
        else:
            state_dict = checkpoint
    
    # Load weights
    model.load_state_dict(state_dict, strict=False)
    model.eval()
    
    return model

def convert_to_coreml(model, output_path, resolution=256):
    """Convert PyTorch model to CoreML"""
    
    # Set model to evaluation mode
    model.eval()
    
    # Create dummy input (4 channels: RGB + mask)
    dummy_input = torch.randn(1, 4, resolution, resolution)
    
    # Trace the model
    print("Tracing the model...")
    with torch.no_grad():
        traced_model = torch.jit.trace(model, dummy_input)
    
    # Convert to CoreML
    print("Converting to CoreML...")
    
    # Define input shape
    input_shape = ct.Shape(shape=(1, 4, resolution, resolution))
    
    # Convert with proper input/output names
    coreml_model = ct.convert(
        traced_model,
        inputs=[ct.TensorType(name="input_image", shape=input_shape)],
        outputs=[ct.TensorType(name="output_image")],
        convert_to="mlprogram"
    )
    
    # Add metadata
    coreml_model.short_description = "MI-GAN Image Inpainting Model"
    coreml_model.input_description["input_image"] = "Input image with mask (4 channels: RGB + mask)"
    coreml_model.output_description["output_image"] = "Inpainted output image (3 channels: RGB)"
    
    # Save the model
    coreml_model.save(output_path)
    print(f"CoreML model saved to: {output_path}")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Convert MI-GAN to CoreML")
    parser.add_argument("--model", required=True, help="Path to MI-GAN model")
    parser.add_argument("--output", required=True, help="Output CoreML model path")
    parser.add_argument("--resolution", type=int, default=256, help="Model resolution")
    
    args = parser.parse_args()
    
    print(f"Loading MI-GAN model from: {args.model}")
    model = load_migan_model(Path(args.model), args.resolution)
    
    print(f"Converting to CoreML format...")
    convert_to_coreml(model, args.output, args.resolution)
    
    print("Conversion completed successfully!")
EOF

# Run the conversion
echo "Converting MI-GAN model to CoreML..."
source ./venv/bin/activate
python /tmp/migan_to_coreml.py \
    --model "$MODEL_PATH" \
    --output "$OUTPUT_PATH" \
    --resolution "$RESOLUTION"

# Clean up temporary file
rm /tmp/migan_to_coreml.py

echo "CoreML export completed!"
echo "Output file: $OUTPUT_PATH"
echo ""
echo "To use the CoreML model in iOS/macOS:"
echo "1. Import the .mlmodel file into your Xcode project"
echo "2. Use Vision framework or Core ML directly to run inference"
echo "3. Input should be 4-channel image (RGB + mask)"
echo "4. Output will be 3-channel RGB inpainted image"