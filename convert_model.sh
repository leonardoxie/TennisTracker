#!/bin/bash
# RacquetVision Model Converter
# Converts YOLOv8 ONNX model to Core ML format for iOS
# 
# Usage: bash convert_model.sh
# Requirements: Python 3.10-3.13 (macOS built-in)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
MODEL_INPUT="$PROJECT_DIR/TennisTracker/TennisDetector.onnx"
MODEL_OUTPUT="$PROJECT_DIR/TennisTracker/YOLOv8.mlpackage"
VENV_DIR="/tmp/racquetvision_venv"

echo "🎾 RacquetVision Model Converter"
echo "================================="

# Check if input model exists
if [ ! -f "$MODEL_INPUT" ]; then
    echo "❌ ONNX model not found at: $MODEL_INPUT"
    echo "   Download it from: https://github.com/Hey-Salad/Tennis_Detection_Model"
    exit 1
fi

# Create venv
echo "📦 Setting up Python environment..."
python3.13 -m venv "$VENV_DIR" --clear 2>/dev/null || python3 -m venv "$VENV_DIR" --clear
source "$VENV_DIR/bin/activate"

# Install dependencies
echo "📥 Installing dependencies (this may take 2-3 minutes)..."
pip install --quiet onnx2torch torch torchvision ultralytics 'coremltools>=9.0' 'numpy>=2.0' onnx

# Convert
echo "🔄 Converting ONNX → Core ML..."
python3 << PYEOF
import sys
print(f"Python: {sys.version}")

# Step 1: ONNX → PyTorch
from onnx2torch import convert
import torch

print("Loading ONNX model...")
torch_model = convert('$MODEL_INPUT')
torch_model.eval()

# Step 2: Trace
print("Tracing model...")
dummy = torch.randn(1, 3, 640, 640)
with torch.no_grad():
    traced = torch.jit.trace(torch_model, dummy)

# Step 3: Convert to Core ML
import coremltools as ct
print("Converting to Core ML...")
coreml_model = ct.convert(
    traced,
    inputs=[ct.TensorType(name="images", shape=(1, 3, 640, 640))],
    minimum_deployment_target=ct.target.iOS16,
    compute_precision=ct.precision.FLOAT16,
)

coreml_model.author = 'RacquetVision'
coreml_model.short_description = 'YOLOv8 Tennis Detection: Player(0), Racket(1), Tennis Ball(2)'

coreml_model.save('$MODEL_OUTPUT')
print(f"✅ Saved to: $MODEL_OUTPUT")

import os
size_mb = sum(os.path.getsize(os.path.join(dp, f)) for dp, dn, fn in os.walk('$MODEL_OUTPUT') for f in fn) / (1024*1024)
print(f"📦 Model size: {size_mb:.1f}MB")
PYEOF

# Clean up
deactivate

echo ""
echo "✅ Done! Model saved to: $MODEL_OUTPUT"
echo "   Classes: Player(0), Racket(1), Tennis Ball(2)"
echo ""
echo "Next steps:"
echo "  1. Open TennisTracker.xcodeproj in Xcode"
echo "  2. Add $MODEL_OUTPUT to the project (drag into Xcode)"
echo "  3. Build and run on your device"
