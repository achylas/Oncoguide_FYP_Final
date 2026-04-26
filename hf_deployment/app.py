"""
OncoGuide v2 - HuggingFace Spaces FastAPI Backend
Endpoints:
  GET  /health                  → server + model status
  POST /validate/mammogram      → MobileNetV3 gatekeeper (grayscale)
  POST /validate/ultrasound     → EfficientNet-B0 gatekeeper (RGB)
  POST /predict/tabular         → Random Forest + SHAP XAI
  POST /analyze/ultrasound      → EfficientNet-B3 U-Net + GradCAM
  POST /analyze/density         → Siamese EfficientNetV2-S (CC+MLO) + GradCAM
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
import torch.nn.functional as F
import timm
import cv2
import os
from PIL import Image
import io
import base64
import zipfile
import tempfile
from torchvision import transforms, models
from efficientnet_pytorch import EfficientNet
import segmentation_models_pytorch as smp
import pydicom

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
DENSITY_PATH      = os.path.join(BASE_DIR, "density_model.pth.zip")

FEATURE_ORDER = [
    'age', 'menarche', 'menopause', 'agefirst', 'children', 'breastfeeding',
    'imc', 'weight', 'menopause_status', 'pregnancy', 'family_history',
    'family_history_count', 'family_history_degree', 'exercise_regular'
]

def _load_state_dict_from_zip_or_direct(path, map_location, suffixes=('.pth', '.pt')):
    """Load a PyTorch state dict from a .zip file or directly."""
    try:
        return torch.load(path, map_location=map_location, weights_only=False)
    except Exception:
        with zipfile.ZipFile(path, 'r') as zf:
            names = zf.namelist()
            print(f"[i] ZIP contents of {os.path.basename(path)}: {names}")
            target = next(
                (f for f in names if any(f.endswith(s) for s in suffixes)),
                names[0]
            )
            with tempfile.NamedTemporaryFile(suffix=os.path.splitext(target)[1], delete=False) as tmp:
                tmp.write(zf.read(target))
                tmp_path = tmp.name
        state_dict = torch.load(tmp_path, map_location=map_location, weights_only=False)
        os.unlink(tmp_path)
        return state_dict


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
            encoder_weights=None
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
# 5. Density Model — Siamese EfficientNetV2-S
# ─────────────────────────────────────────────
DENSITY_LABELS = [
    "Density A (Fatty)",
    "Density B (Scattered)",
    "Density C (Heterogeneous)",
    "Density D (Extremely Dense)",
]
DENSITY_LABEL_SHORT = ["A - Fatty", "B - Scattered", "C - Heterogeneous", "D - Extremely Dense"]

def _get_efficientnet_v2s():
    """EfficientNetV2-S backbone (features only)."""
    m = models.efficientnet_v2_s(weights=None)
    return m.features, 1280

class SiameseEfficientNet(nn.Module):
    """Siamese network: takes CC + MLO views, outputs 4-class density."""
    def __init__(self, num_classes: int = 4):
        super().__init__()
        self.backbone, self.feat_dim = _get_efficientnet_v2s()
        self.pool = nn.AdaptiveAvgPool2d(1)
        self.classifier = nn.Sequential(
            nn.Linear(self.feat_dim * 2, 512),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(512, num_classes),
        )

    def forward(self, cc: torch.Tensor, mlo: torch.Tensor) -> torch.Tensor:
        f1 = self.pool(self.backbone(cc)).flatten(1)
        f2 = self.pool(self.backbone(mlo)).flatten(1)
        return self.classifier(torch.cat([f1, f2], dim=1))


density_model  = None
density_device = torch.device("cpu")

if os.path.exists(DENSITY_PATH):
    try:
        density_model = SiameseEfficientNet(num_classes=4)
        state_dict    = _load_state_dict_from_zip_or_direct(
            DENSITY_PATH, density_device, suffixes=('.pth', '.pt')
        )
        # Handle checkpoint wrappers
        if isinstance(state_dict, dict):
            for key in ('model_state_dict', 'state_dict', 'model'):
                if key in state_dict:
                    state_dict = state_dict[key]
                    break
        density_model.load_state_dict(state_dict, strict=True)
        density_model.to(density_device)
        density_model.eval()
        print("[✓] Density model loaded")
    except Exception as e:
        print(f"[✗] Density model load error: {e}")
        density_model = None
else:
    print(f"[✗] Density model not found at {DENSITY_PATH}")


# ── Density preprocessing ──────────────────────────────────────────────────

def _preprocess_density_image(file_bytes: bytes, target_size: int = 1024) -> np.ndarray:
    """
    Decode (JPEG/PNG/DICOM) → normalise → crop breast → align orientation → CLAHE.
    Returns a uint8 grayscale numpy array of shape (target_size, target_size).
    """
    # Try DICOM first, then fall back to standard image formats
    img = None
    try:
        ds  = pydicom.dcmread(io.BytesIO(file_bytes))
        img = ds.pixel_array.astype(np.float32)
        # MONOCHROME1 means bright = air (invert so tissue is bright)
        if getattr(ds, "PhotometricInterpretation", "") == "MONOCHROME1":
            img = img.max() - img
    except Exception:
        pass  # not a DICOM file

    if img is None:
        nparr = np.frombuffer(file_bytes, np.uint8)
        img   = cv2.imdecode(nparr, cv2.IMREAD_GRAYSCALE)
        if img is None:
            raise ValueError("Could not decode image. Use JPEG, PNG, or DICOM.")
        img = img.astype(np.float32)

    # Normalise to [0, 255]
    img = (img - img.min()) / (img.max() - img.min() + 1e-7)
    img = (img * 255).astype(np.uint8)

    # Crop breast region
    _, thresh = cv2.threshold(img, 5, 255, cv2.THRESH_BINARY)
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if contours:
        cnt = max(contours, key=cv2.contourArea)
        x, y, w, h = cv2.boundingRect(cnt)
        img = img[y:y + h, x:x + w]

    # Resize keeping aspect ratio, pad to square
    h, w   = img.shape
    scale  = target_size / max(h, w)
    new_w  = int(w * scale)
    new_h  = int(h * scale)
    resized = cv2.resize(img, (new_w, new_h))

    canvas = np.zeros((target_size, target_size), dtype=np.uint8)

    # Orientation alignment (left vs right breast)
    left_sum  = np.sum(img[:, :w // 2])
    right_sum = np.sum(img[:, w // 2:])
    is_right  = right_sum > left_sum

    dy = (target_size - new_h) // 2
    dx = (target_size - new_w) if is_right else 0
    canvas[dy:dy + new_h, dx:dx + new_w] = resized

    # CLAHE enhancement
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return clahe.apply(canvas)


def _density_to_tensor(img: np.ndarray, size: int = 384) -> torch.Tensor:
    """Grayscale uint8 → 3-channel float tensor [1, 3, size, size]."""
    resized = cv2.resize(img, (size, size))
    rgb     = np.stack([resized, resized, resized], axis=-1)   # H×W×3
    tensor  = torch.from_numpy(rgb).permute(2, 0, 1).float() / 255.0
    return tensor.unsqueeze(0)   # [1, 3, H, W]


def _density_gradcam(
    model: SiameseEfficientNet,
    cc_t: torch.Tensor,
    mlo_t: torch.Tensor,
    target_class: int,
    cc_img: np.ndarray,
) -> str:
    """
    Compute GradCAM on the CC view and return a base64-encoded PNG overlay.

    Strategy: use forward hooks to capture the last backbone feature map
    (activations) and its gradients in a single forward+backward pass,
    avoiding the stale-activation bug that arises when re-running the
    backbone inside torch.no_grad() after the gradient pass.
    """
    model.eval()

    # ── Hook storage ──────────────────────────────────────────────────────
    _acts: dict  = {}
    _grads: dict = {}

    # Target the last conv block of EfficientNetV2-S features
    # model.backbone is nn.Sequential; last meaningful block is index -1
    target_layer = model.backbone[-1]

    def _fwd_hook(module, inp, out):
        _acts['value'] = out  # keep as tensor (with grad_fn)

    def _bwd_hook(module, grad_in, grad_out):
        _grads['value'] = grad_out[0].detach()

    fwd_h = target_layer.register_forward_hook(_fwd_hook)
    bwd_h = target_layer.register_full_backward_hook(_bwd_hook)

    try:
        # Single forward pass — activations captured by hook
        cc_req  = cc_t.clone().requires_grad_(True)
        mlo_req = mlo_t.clone()

        output = model(cc_req, mlo_req)
        model.zero_grad()
        output[0, target_class].backward()
    finally:
        fwd_h.remove()
        bwd_h.remove()

    if 'value' not in _grads or 'value' not in _acts:
        return ""

    grads = _grads['value']                          # [1, C, H, W]
    acts  = _acts['value'].detach()                  # [1, C, H, W]

    # Global-average-pool the gradients → channel weights
    pooled = grads.mean(dim=[2, 3], keepdim=True)    # [1, C, 1, 1]

    # Weighted combination of activation maps
    cam = (pooled * acts).sum(dim=1, keepdim=True)   # [1, 1, H, W]
    cam = torch.relu(cam).squeeze().cpu().numpy()    # ReLU + squeeze

    # Normalise to [0, 1]
    cam = cam / (cam.max() + 1e-7)

    # Resize and colourise
    display_size    = 384
    cam_resized     = cv2.resize(cam, (display_size, display_size))
    heatmap_uint8   = (cam_resized * 255).astype(np.uint8)
    colored         = cv2.applyColorMap(heatmap_uint8, cv2.COLORMAP_JET)

    # Overlay on original CC image
    cc_display = cv2.resize(cc_img, (display_size, display_size))
    cc_rgb     = cv2.cvtColor(cc_display, cv2.COLOR_GRAY2RGB)
    overlay    = cv2.addWeighted(cc_rgb, 0.6, colored, 0.4, 0)

    pil_img = Image.fromarray(overlay)
    buf     = io.BytesIO()
    pil_img.save(buf, format='PNG')
    return base64.b64encode(buf.getvalue()).decode('utf-8')


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

class DensityAnalysisResult(BaseModel):
    density_class: str       # e.g. "Density B (Scattered)"
    density_label: str       # short label e.g. "B - Scattered"
    density_index: int       # 0=A, 1=B, 2=C, 3=D
    confidence: float        # 0–100
    probabilities: dict      # class → probability %
    gradcam_image: str       # base64 encoded PNG heatmap overlay (CC view)

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
        "rf_model_loaded":          rf_model is not None,
        "mammo_gate_loaded":        mammo_model is not None,
        "us_gate_loaded":           us_model is not None,
        "us_analysis_loaded":       us_analysis_model is not None,
        "density_model_loaded":     density_model is not None,
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


@app.post("/analyze/density", response_model=DensityAnalysisResult)
async def analyze_density(
    cc_file:  UploadFile = File(..., description="CC (cranio-caudal) mammogram view"),
    mlo_file: UploadFile = File(..., description="MLO (medio-lateral oblique) mammogram view"),
):
    """
    Classify mammogram breast density (BI-RADS A–D) using a Siamese EfficientNetV2-S.
    Requires two views: CC and MLO.
    Returns density class, per-class probabilities, and a GradCAM heatmap of the CC view.
    """
    if density_model is None:
        raise HTTPException(status_code=503, detail="Density model not loaded.")

    allowed = {"image/jpeg", "image/png", "image/jpg",
               "application/dicom", "application/octet-stream"}
    for f, name in [(cc_file, "cc_file"), (mlo_file, "mlo_file")]:
        if f.content_type not in allowed:
            raise HTTPException(
                status_code=400,
                detail=f"{name}: use JPEG, PNG, or DICOM (got {f.content_type})."
            )

    cc_bytes  = await cc_file.read()
    mlo_bytes = await mlo_file.read()

    try:
        cc_proc  = _preprocess_density_image(cc_bytes)
        mlo_proc = _preprocess_density_image(mlo_bytes)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    cc_t  = _density_to_tensor(cc_proc).to(density_device)
    mlo_t = _density_to_tensor(mlo_proc).to(density_device)

    # ── Inference ─────────────────────────────────────────────────────────
    with torch.no_grad():
        logits = density_model(cc_t, mlo_t)
        probs  = F.softmax(logits, dim=1)[0]

    pred_idx   = int(torch.argmax(probs).item())
    confidence = round(float(probs[pred_idx].item()) * 100, 2)

    probabilities = {
        DENSITY_LABELS[i]: round(float(probs[i].item()) * 100, 2)
        for i in range(len(DENSITY_LABELS))
    }

    # ── GradCAM on CC view ────────────────────────────────────────────────
    try:
        gradcam_b64 = _density_gradcam(
            density_model, cc_t, mlo_t, pred_idx, cc_proc
        )
    except Exception as e:
        print(f"[!] Density GradCAM failed: {e}")
        gradcam_b64 = ""

    return DensityAnalysisResult(
        density_class=DENSITY_LABELS[pred_idx],
        density_label=DENSITY_LABEL_SHORT[pred_idx],
        density_index=pred_idx,
        confidence=confidence,
        probabilities=probabilities,
        gradcam_image=gradcam_b64,
    )


if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=7860)
