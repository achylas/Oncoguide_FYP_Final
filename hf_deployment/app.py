"""
OncoGuide v2 - HuggingFace Spaces FastAPI Backend
Endpoints:
  GET  /health                  → server + model status
  POST /validate/mammogram      → MobileNetV3 gatekeeper (grayscale)
  POST /validate/ultrasound     → EfficientNet-B0 gatekeeper (RGB)
  POST /predict/tabular         → Random Forest + SHAP XAI
"""

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import numpy as np
import pandas as pd
import joblib
import shap
import torch
import torch.nn as nn
import timm
import cv2
import os
from PIL import Image
import io
import base64
from torchvision import transforms
from efficientnet_pytorch import EfficientNet
import segmentation_models_pytorch as smp

# ─────────────────────────────────────────────
# App setup
# ─────────────────────────────────────────────
app = FastAPI(title="OncoGuide AI API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR          = os.path.dirname(os.path.abspath(__file__))
RF_MODEL_PATH     = os.path.join(BASE_DIR, "rf_breast_cancer.pkl")
MAMMO_GATE_PATH   = os.path.join(BASE_DIR, "gatekeeper_best_v3.pth.zip")
US_GATE_PATH      = os.path.join(BASE_DIR, "us_gatekeeper.pt.zip")
US_ANALYSIS_PATH  = os.path.join(BASE_DIR, "us_analysis.pth.zip")

FEATURE_ORDER = [
    'age', 'menarche', 'menopause', 'agefirst', 'children', 'breastfeeding',
    'imc', 'weight', 'menopause_status', 'pregnancy', 'family_history',
    'family_history_count', 'family_history_degree', 'exercise_regular'
]

# ─────────────────────────────────────────────
# 1. Load Random Forest + SHAP
# ─────────────────────────────────────────────
rf_model       = None
shap_explainer = None

if os.path.exists(RF_MODEL_PATH):
    rf_model       = joblib.load(RF_MODEL_PATH)
    shap_explainer = shap.TreeExplainer(rf_model)
    print("[✓] Random Forest + SHAP loaded")
else:
    print(f"[✗] RF model not found at {RF_MODEL_PATH}")

# ─────────────────────────────────────────────
# 2. Load Mammogram Gatekeeper (MobileNetV3)
# ─────────────────────────────────────────────
def _create_mammo_gatekeeper():
    model = timm.create_model(
        'mobilenetv3_large_100', pretrained=False, in_chans=1, num_classes=1
    )
    model.classifier = nn.Sequential(
        nn.Linear(1280, 512),
        nn.Hardswish(),
        nn.Dropout(p=0.2),
        nn.Linear(512, 1)
    )
    return model

mammo_model  = None
mammo_device = torch.device("cpu")

if os.path.exists(MAMMO_GATE_PATH):
    mammo_model = _create_mammo_gatekeeper()
    state_dict  = torch.load(MAMMO_GATE_PATH, map_location=mammo_device, weights_only=False)
    if any(k.startswith('model.') for k in state_dict.keys()):
        state_dict = {k.replace('model.', ''): v for k, v in state_dict.items()}
    mammo_model.load_state_dict(state_dict)
    mammo_model.eval()
    print("[✓] Mammogram gatekeeper loaded")
else:
    print(f"[✗] Mammogram gatekeeper not found at {MAMMO_GATE_PATH}")

# ─────────────────────────────────────────────
# 3. Load Ultrasound Gatekeeper (EfficientNet-B0)
# ─────────────────────────────────────────────
def _create_us_gatekeeper():
    model = EfficientNet.from_name('efficientnet-b0')
    num_ftrs = model._fc.in_features
    model._fc = nn.Sequential(
        nn.Linear(num_ftrs, 1),
        nn.Sigmoid()
    )
    return model

us_model  = None
us_device = torch.device("cpu")

if os.path.exists(US_GATE_PATH):
    try:
        us_model = _create_us_gatekeeper()
        import zipfile, tempfile

        # Try direct torch.load first (works if it's a PyTorch zip format)
        try:
            state_dict = torch.load(US_GATE_PATH, map_location=us_device, weights_only=False)
        except Exception:
            # Fallback: extract from zip then load
            with zipfile.ZipFile(US_GATE_PATH, 'r') as zf:
                names = zf.namelist()
                print(f"[i] ZIP contents: {names}")
                target = next((f for f in names if f.endswith('.pt')), names[0])
                with tempfile.NamedTemporaryFile(suffix='.pt', delete=False) as tmp:
                    tmp.write(zf.read(target))
                    tmp_path = tmp.name
            state_dict = torch.load(tmp_path, map_location=us_device, weights_only=False)
            os.unlink(tmp_path)

        # Fix key prefixes if needed
        new_state_dict = {}
        for k, v in state_dict.items():
            new_key = k.replace('encoder.', '_').replace('classifier.', '_fc.')
            new_state_dict[new_key] = v
        us_model.load_state_dict(new_state_dict, strict=False)
        us_model.eval()
        print("[✓] Ultrasound gatekeeper loaded")
    except Exception as e:
        print(f"[✗] Ultrasound gatekeeper load error: {e}")
        us_model = None
else:
    print(f"[✗] Ultrasound gatekeeper not found at {US_GATE_PATH}")

# ─────────────────────────────────────────────
# Preprocessing helpers
# ─────────────────────────────────────────────
def _preprocess_mammogram(file_bytes: bytes, img_size: int = 224):
    """Grayscale → normalise to [-1, 1] → tensor [1,1,224,224]"""
    nparr   = np.frombuffer(file_bytes, np.uint8)
    img     = cv2.imdecode(nparr, cv2.IMREAD_GRAYSCALE)
    if img is None:
        raise ValueError("Could not decode image. Use JPEG or PNG.")
    resized = cv2.resize(img, (img_size, img_size))
    tensor  = torch.from_numpy(resized).float() / 255.0
    tensor  = (tensor - 0.5) / 0.5
    tensor  = tensor.unsqueeze(0).unsqueeze(0)   # [1,1,224,224]
    return tensor

_us_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

def _preprocess_ultrasound(file_bytes: bytes):
    """RGB → ImageNet normalise → tensor [1,3,224,224]"""
    img = Image.open(io.BytesIO(file_bytes)).convert("RGB")
    return _us_transform(img).unsqueeze(0).to(us_device)

# ─────────────────────────────────────────────
# 4. Load Ultrasound Analysis Model (DualOutputModel)
# ─────────────────────────────────────────────
US_CLASSES     = ['benign', 'normal', 'malignant']
US_CLASS_NAMES = {0: 'Benign', 1: 'Normal', 2: 'Malignant'}

class DualOutputModel(nn.Module):
    """EfficientNet-B3 encoder with classification head (inference only)."""
    def __init__(self, num_classes=3, encoder_name="efficientnet-b3",
                 encoder_weights=None):
        super().__init__()
        # Full U-Net needed to match saved weights exactly
        self.unet = smp.Unet(
            encoder_name=encoder_name,
            encoder_weights=encoder_weights,
            in_channels=3,
            classes=1,
        )
        encoder_channels = self.unet.encoder.out_channels
        bottleneck_ch = encoder_channels[-1]
        self.classification_head = nn.Sequential(
            nn.AdaptiveAvgPool2d(1),
            nn.Flatten(),
            nn.Linear(bottleneck_ch, 256),
            nn.ReLU(),
            nn.Dropout(0.5),
            nn.Linear(256, num_classes),
        )

    def forward(self, x):
        # Only run encoder + classification head (skip decoder for inference)
        features   = self.unet.encoder(x)
        cls_output = self.classification_head(features[-1])
        # Return dummy seg + cls to match training signature
        return None, cls_output

us_analysis_model  = None
us_analysis_device = torch.device("cpu")

if os.path.exists(US_ANALYSIS_PATH):
    try:
        us_analysis_model = DualOutputModel(
            num_classes=3,
            encoder_name="efficientnet-b3",
            encoder_weights=None   # weights loaded from checkpoint
        )
        import zipfile, tempfile
        try:
            state_dict = torch.load(US_ANALYSIS_PATH, map_location=us_analysis_device, weights_only=False)
        except Exception:
            with zipfile.ZipFile(US_ANALYSIS_PATH, 'r') as zf:
                names = zf.namelist()
                print(f"[i] US analysis ZIP contents: {names}")
                target = next((f for f in names if f.endswith('.pth')), names[0])
                with tempfile.NamedTemporaryFile(suffix='.pth', delete=False) as tmp:
                    tmp.write(zf.read(target))
                    tmp_path = tmp.name
            state_dict = torch.load(tmp_path, map_location=us_analysis_device, weights_only=False)
            os.unlink(tmp_path)

        # Handle checkpoint dict vs raw state_dict
        if isinstance(state_dict, dict) and 'model_state_dict' in state_dict:
            state_dict = state_dict['model_state_dict']
        elif isinstance(state_dict, dict) and 'state_dict' in state_dict:
            state_dict = state_dict['state_dict']

        us_analysis_model.load_state_dict(state_dict, strict=False)
        us_analysis_model.to(us_analysis_device)
        us_analysis_model.eval()
        print("[✓] Ultrasound analysis model loaded")
    except Exception as e:
        print(f"[✗] Ultrasound analysis model load error: {e}")
        us_analysis_model = None
else:
    print(f"[✗] Ultrasound analysis model not found at {US_ANALYSIS_PATH}")

# ─────────────────────────────────────────────
# Schemas
# ─────────────────────────────────────────────
class TabularInput(BaseModel):
    age: float
    menarche: float
    menopause: float
    agefirst: float
    children: float
    breastfeeding: int
    imc: float
    weight: float
    menopause_status: int
    pregnancy: int
    family_history: int
    family_history_count: float
    family_history_degree: float
    exercise_regular: int

class TabularResult(BaseModel):
    prediction: int
    probability: float
    risk_label: str
    risk_percentage: float
    shap_values: dict
    base_value: float

class ImageValidationResult(BaseModel):
    is_valid: bool
    score: float
    message: str

class UltrasoundAnalysisResult(BaseModel):
    prediction: str          # "Benign" | "Normal" | "Malignant"
    prediction_index: int    # 0=benign, 1=normal, 2=malignant
    confidence: float        # 0–100
    probabilities: dict      # class → probability %
    gradcam_image: str       # base64 encoded PNG heatmap overlay

# ─────────────────────────────────────────────
# GradCAM helper
# ─────────────────────────────────────────────
def _compute_gradcam(model, tensor, target_class_idx, device):
    """
    Computes GradCAM heatmap for the given input tensor.
    Returns a base64-encoded PNG of the heatmap overlaid on the input image.
    """
    model.eval()

    # Storage for activations and gradients
    activations = {}
    gradients   = {}

    # Hook the last conv layer of EfficientNet encoder
    # In SMP EfficientNet-B3, the last encoder block is accessible via:
    target_layer = model.unet.encoder._blocks[-1]

    def forward_hook(module, input, output):
        activations['value'] = output.detach()

    def backward_hook(module, grad_input, grad_output):
        gradients['value'] = grad_output[0].detach()

    fwd_handle = target_layer.register_forward_hook(forward_hook)
    bwd_handle = target_layer.register_full_backward_hook(backward_hook)

    # Forward pass
    tensor_req = tensor.clone().requires_grad_(True).to(device)
    _, cls_logits = model(tensor_req)

    # Backward pass for target class
    model.zero_grad()
    cls_logits[0, target_class_idx].backward()

    fwd_handle.remove()
    bwd_handle.remove()

    # Compute GradCAM
    grads  = gradients['value']          # [1, C, H, W]
    acts   = activations['value']        # [1, C, H, W]
    weights = grads.mean(dim=[2, 3], keepdim=True)  # global avg pool
    cam    = (weights * acts).sum(dim=1, keepdim=True)  # [1, 1, H, W]
    cam    = torch.relu(cam)
    cam    = cam.squeeze().cpu().numpy()

    # Normalise to [0, 1]
    if cam.max() > cam.min():
        cam = (cam - cam.min()) / (cam.max() - cam.min())
    else:
        cam = np.zeros_like(cam)

    # Resize to 224×224
    cam_resized = cv2.resize(cam, (224, 224))

    # Convert to colour heatmap
    heatmap = cv2.applyColorMap(
        (cam_resized * 255).astype(np.uint8), cv2.COLORMAP_JET
    )
    heatmap = cv2.cvtColor(heatmap, cv2.COLOR_BGR2RGB)

    # Get original image as numpy (denormalise)
    mean = np.array([0.485, 0.456, 0.406])
    std  = np.array([0.229, 0.224, 0.225])
    orig = tensor.squeeze().cpu().numpy().transpose(1, 2, 0)
    orig = (orig * std + mean)
    orig = np.clip(orig * 255, 0, 255).astype(np.uint8)
    orig = cv2.resize(orig, (224, 224))

    # Overlay heatmap on original image
    overlay = cv2.addWeighted(orig, 0.6, heatmap, 0.4, 0)

    # Encode to base64 PNG
    pil_img = Image.fromarray(overlay)
    buf = io.BytesIO()
    pil_img.save(buf, format='PNG')
    b64 = base64.b64encode(buf.getvalue()).decode('utf-8')
    return b64


# ─────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────
@app.get("/health")
def health():
    return {
        "status": "ok",
        "rf_model_loaded":       rf_model is not None,
        "mammo_gate_loaded":     mammo_model is not None,
        "us_gate_loaded":        us_model is not None,
    }


@app.post("/predict/tabular", response_model=TabularResult)
def predict_tabular(data: TabularInput):
    if rf_model is None:
        raise HTTPException(status_code=503, detail="Tabular model not loaded.")

    input_df    = pd.DataFrame([data.dict()])[FEATURE_ORDER]
    prediction  = int(rf_model.predict(input_df)[0])
    probability = float(rf_model.predict_proba(input_df)[0][1])

    sv_raw = shap_explainer.shap_values(input_df)
    if isinstance(sv_raw, np.ndarray) and sv_raw.ndim == 3:
        sv   = sv_raw[0, :, 1]
        base = float(shap_explainer.expected_value[1])
    elif isinstance(sv_raw, list):
        sv   = sv_raw[1][0]
        base = float(shap_explainer.expected_value[1])
    else:
        sv   = sv_raw[0]
        base = float(shap_explainer.expected_value)

    shap_dict = {
        FEATURE_ORDER[i]: round(float(sv[i]), 6)
        for i in range(len(FEATURE_ORDER))
    }

    return TabularResult(
        prediction=prediction,
        probability=probability,
        risk_label="High Risk" if prediction == 1 else "Low Risk",
        risk_percentage=round(probability * 100, 2),
        shap_values=shap_dict,
        base_value=round(base, 6),
    )


@app.post("/validate/mammogram", response_model=ImageValidationResult)
async def validate_mammogram(file: UploadFile = File(...)):
    if mammo_model is None:
        raise HTTPException(status_code=503, detail="Mammogram gatekeeper not loaded.")

    allowed = {"image/jpeg", "image/png", "image/jpg"}
    if file.content_type not in allowed:
        raise HTTPException(status_code=400, detail=f"Use JPEG or PNG.")

    file_bytes = await file.read()
    try:
        tensor = _preprocess_mammogram(file_bytes)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    with torch.no_grad():
        score = float(torch.sigmoid(mammo_model(tensor)).item())

    is_valid = score > 0.8
    message  = (
        "Valid mammogram image detected. Proceeding with analysis."
        if is_valid else
        "Image does not appear to be a valid mammogram. Please upload a proper mammogram scan."
    )
    return ImageValidationResult(is_valid=is_valid, score=round(score, 4), message=message)


@app.post("/validate/ultrasound", response_model=ImageValidationResult)
async def validate_ultrasound(file: UploadFile = File(...)):
    if us_model is None:
        raise HTTPException(status_code=503, detail="Ultrasound gatekeeper not loaded.")

    allowed = {"image/jpeg", "image/png", "image/jpg"}
    if file.content_type not in allowed:
        raise HTTPException(status_code=400, detail=f"Use JPEG or PNG.")

    file_bytes = await file.read()
    try:
        tensor = _preprocess_ultrasound(file_bytes)
    except Exception as e:
        raise HTTPException(status_code=422, detail=str(e))

    with torch.no_grad():
        # EfficientNet head already has Sigmoid — score < 0.5 = valid ultrasound
        prob  = float(us_model(tensor).item())

    is_valid = prob < 0.5
    score    = round((1 - prob) * 100 if is_valid else prob * 100, 2)
    message  = (
        "Valid ultrasound image detected. Proceeding with analysis."
        if is_valid else
        "Image does not appear to be a valid ultrasound. Please upload a proper ultrasound scan."
    )
    return ImageValidationResult(is_valid=is_valid, score=round(score / 100, 4), message=message)


@app.post("/analyze/ultrasound", response_model=UltrasoundAnalysisResult)
async def analyze_ultrasound(file: UploadFile = File(...)):
    if us_analysis_model is None:
        raise HTTPException(status_code=503, detail="Ultrasound analysis model not loaded.")

    allowed = {"image/jpeg", "image/png", "image/jpg"}
    if file.content_type not in allowed:
        raise HTTPException(status_code=400, detail="Use JPEG or PNG.")

    file_bytes = await file.read()
    try:
        tensor = _preprocess_ultrasound(file_bytes)
    except Exception as e:
        raise HTTPException(status_code=422, detail=str(e))

    # ── Classification ────────────────────────────────────────────────────
    with torch.no_grad():
        _, cls_logits = us_analysis_model(tensor.to(us_analysis_device))
        probs = torch.softmax(cls_logits, dim=1)[0]

    pred_idx   = int(torch.argmax(probs).item())
    pred_label = US_CLASS_NAMES[pred_idx]
    confidence = round(float(probs[pred_idx].item()) * 100, 2)

    probabilities = {
        US_CLASS_NAMES[i]: round(float(probs[i].item()) * 100, 2)
        for i in range(len(US_CLASSES))
    }

    # ── GradCAM ───────────────────────────────────────────────────────────
    try:
        gradcam_b64 = _compute_gradcam(
            us_analysis_model, tensor, pred_idx, us_analysis_device
        )
    except Exception as e:
        print(f"[!] GradCAM failed: {e}")
        gradcam_b64 = ""   # return empty string if GradCAM fails

    return UltrasoundAnalysisResult(
        prediction=pred_label,
        prediction_index=pred_idx,
        confidence=confidence,
        probabilities=probabilities,
        gradcam_image=gradcam_b64,
    )


if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=7860)
