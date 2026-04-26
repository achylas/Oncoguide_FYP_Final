"""
OncoGuide v2 — Mammogram Density Model: Local Streamlit Prototype
=================================================================
This file is a standalone Streamlit app for local testing of the
Siamese EfficientNetV2-S breast density classifier.

For the production deployment, see: ../hf_deployment/app.py
  → POST /analyze/density  (FastAPI endpoint, HuggingFace Spaces)

Usage:
    pip install streamlit torch torchvision opencv-python pydicom Pillow
    streamlit run density_deployment.py

Expects density_model.pth (or density_model.pth.zip) in the same directory.
"""

import io
import zipfile
import tempfile

import streamlit as st
import torch
import torch.nn as nn
import torch.nn.functional as F
import cv2
import numpy as np
import pydicom
from PIL import Image
from torchvision import models


# ─────────────────────────────────────────────────────────────────────────────
# 1. Model Architecture
# ─────────────────────────────────────────────────────────────────────────────

def _get_efficientnet_v2s():
    """EfficientNetV2-S backbone (features only), returns (backbone, feat_dim)."""
    m = models.efficientnet_v2_s(weights=None)
    return m.features, 1280


class SiameseEfficientNet(nn.Module):
    """
    Siamese network that takes two mammogram views (CC + MLO) and outputs
    a 4-class breast density prediction (BI-RADS A–D).
    """
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


# ─────────────────────────────────────────────────────────────────────────────
# 2. Preprocessing
# ─────────────────────────────────────────────────────────────────────────────

def load_image(uploaded_file) -> np.ndarray:
    """
    Load a DICOM, PNG, or JPEG file into a uint8 grayscale numpy array.
    Handles MONOCHROME1 inversion for DICOM files.
    """
    name = uploaded_file.name.lower()
    if name.endswith('.dcm'):
        ds  = pydicom.dcmread(uploaded_file)
        img = ds.pixel_array.astype(np.float32)
        if getattr(ds, "PhotometricInterpretation", "") == "MONOCHROME1":
            img = img.max() - img
    else:
        file_bytes = np.asarray(bytearray(uploaded_file.read()), dtype=np.uint8)
        img = cv2.imdecode(file_bytes, cv2.IMREAD_GRAYSCALE).astype(np.float32)

    img = (img - img.min()) / (img.max() - img.min() + 1e-7)
    return (img * 255).astype(np.uint8)


def preprocess(img: np.ndarray, target_size: int = 1024) -> np.ndarray:
    """
    Normalise → crop breast region → align orientation → CLAHE.
    Returns a uint8 grayscale array of shape (target_size, target_size).
    """
    # Crop breast
    _, thresh = cv2.threshold(img, 5, 255, cv2.THRESH_BINARY)
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if contours:
        cnt = max(contours, key=cv2.contourArea)
        x, y, w, h = cv2.boundingRect(cnt)
        img = img[y:y + h, x:x + w]

    # Resize keeping aspect ratio, pad to square
    h, w   = img.shape
    scale  = target_size / max(h, w)
    new_w, new_h = int(w * scale), int(h * scale)
    resized = cv2.resize(img, (new_w, new_h))

    canvas = np.zeros((target_size, target_size), dtype=np.uint8)

    # Orientation alignment
    left_sum  = np.sum(img[:, :w // 2])
    right_sum = np.sum(img[:, w // 2:])
    is_right  = right_sum > left_sum

    dy = (target_size - new_h) // 2
    dx = (target_size - new_w) if is_right else 0
    canvas[dy:dy + new_h, dx:dx + new_w] = resized

    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return clahe.apply(canvas)


def to_tensor(img: np.ndarray, size: int = 384) -> torch.Tensor:
    """Grayscale uint8 → 3-channel float tensor [1, 3, size, size]."""
    resized = cv2.resize(img, (size, size))
    rgb     = np.stack([resized, resized, resized], axis=-1)
    return torch.from_numpy(rgb).permute(2, 0, 1).float().unsqueeze(0) / 255.0


# ─────────────────────────────────────────────────────────────────────────────
# 3. GradCAM
# ─────────────────────────────────────────────────────────────────────────────

def gradcam(
    model: SiameseEfficientNet,
    cc_t: torch.Tensor,
    mlo_t: torch.Tensor,
    target_class: int,
    cc_img: np.ndarray,
) -> np.ndarray:
    """
    Compute GradCAM on the CC view using forward/backward hooks.
    Returns an RGB overlay numpy array (384×384×3).
    """
    model.eval()

    _acts: dict  = {}
    _grads: dict = {}

    target_layer = model.backbone[-1]

    def _fwd(module, inp, out):
        _acts['v'] = out

    def _bwd(module, gin, gout):
        _grads['v'] = gout[0].detach()

    fh = target_layer.register_forward_hook(_fwd)
    bh = target_layer.register_full_backward_hook(_bwd)

    try:
        cc_req = cc_t.clone().requires_grad_(True)
        out    = model(cc_req, mlo_t.clone())
        model.zero_grad()
        out[0, target_class].backward()
    finally:
        fh.remove()
        bh.remove()

    if 'v' not in _grads or 'v' not in _acts:
        return cv2.cvtColor(cv2.resize(cc_img, (384, 384)), cv2.COLOR_GRAY2RGB)

    grads  = _grads['v']
    acts   = _acts['v'].detach()
    pooled = grads.mean(dim=[2, 3], keepdim=True)
    cam    = torch.relu((pooled * acts).sum(dim=1)).squeeze().cpu().numpy()
    cam    = cam / (cam.max() + 1e-7)

    cam_r   = cv2.resize(cam, (384, 384))
    colored = cv2.applyColorMap((cam_r * 255).astype(np.uint8), cv2.COLORMAP_JET)
    cc_disp = cv2.cvtColor(cv2.resize(cc_img, (384, 384)), cv2.COLOR_GRAY2RGB)
    return cv2.addWeighted(cc_disp, 0.6, colored, 0.4, 0)


# ─────────────────────────────────────────────────────────────────────────────
# 4. Model Loading
# ─────────────────────────────────────────────────────────────────────────────

@st.cache_resource
def load_model(path: str = "density_model.pth") -> SiameseEfficientNet | None:
    """Load model weights from .pth or .pth.zip file."""
    import os
    zip_path = path + ".zip" if not path.endswith(".zip") else path
    pth_path = path if not path.endswith(".zip") else path[:-4]

    state_dict = None

    # Try direct .pth load
    if os.path.exists(pth_path):
        try:
            state_dict = torch.load(pth_path, map_location="cpu", weights_only=False)
        except Exception as e:
            st.warning(f"Direct load failed: {e}")

    # Try .zip extraction
    if state_dict is None and os.path.exists(zip_path):
        try:
            with zipfile.ZipFile(zip_path, 'r') as zf:
                names  = zf.namelist()
                target = next((f for f in names if f.endswith('.pth')), names[0])
                with tempfile.NamedTemporaryFile(suffix='.pth', delete=False) as tmp:
                    tmp.write(zf.read(target))
                    tmp_path = tmp.name
            state_dict = torch.load(tmp_path, map_location="cpu", weights_only=False)
            import os as _os; _os.unlink(tmp_path)
        except Exception as e:
            st.error(f"ZIP load failed: {e}")
            return None

    if state_dict is None:
        st.error("Model file not found. Place density_model.pth or density_model.pth.zip here.")
        return None

    # Unwrap checkpoint dicts
    for key in ('model_state_dict', 'state_dict', 'model'):
        if isinstance(state_dict, dict) and key in state_dict:
            state_dict = state_dict[key]
            break

    model = SiameseEfficientNet(num_classes=4)
    model.load_state_dict(state_dict, strict=True)
    model.eval()
    return model


# ─────────────────────────────────────────────────────────────────────────────
# 5. Streamlit UI
# ─────────────────────────────────────────────────────────────────────────────

DENSITY_LABELS = [
    "Density A (Fatty)",
    "Density B (Scattered)",
    "Density C (Heterogeneous)",
    "Density D (Extremely Dense)",
]
CLINICAL_NOTES = [
    "Fatty tissue — highest sensitivity for mammography.",
    "Scattered fibroglandular — generally good sensitivity.",
    "Heterogeneous dense — may obscure small masses.",
    "Extremely dense — significantly reduces mammography sensitivity.",
]

st.set_page_config(page_title="OncoGuide — Breast Density AI", layout="wide")
st.title("🩺 Breast Density Classification (BI-RADS A–D)")
st.caption("Siamese EfficientNetV2-S · CC + MLO views · GradCAM explainability")

st.sidebar.header("Upload Mammogram Views")
cc_file  = st.sidebar.file_uploader("CC View",  type=['dcm', 'png', 'jpg', 'jpeg'])
mlo_file = st.sidebar.file_uploader("MLO View", type=['dcm', 'png', 'jpg', 'jpeg'])

if cc_file and mlo_file:
    cc_raw  = load_image(cc_file)
    mlo_raw = load_image(mlo_file)
    cc_proc  = preprocess(cc_raw)
    mlo_proc = preprocess(mlo_raw)

    st.subheader("📋 Uploaded Images")
    col1, col2, col3, col4 = st.columns(4)
    col1.image(cc_raw,   caption="CC — Original",   use_container_width=True)
    col2.image(cc_proc,  caption="CC — Processed",  use_container_width=True)
    col3.image(mlo_raw,  caption="MLO — Original",  use_container_width=True)
    col4.image(mlo_proc, caption="MLO — Processed", use_container_width=True)

    if st.button("🚀 Run Density Analysis"):
        with st.spinner("Loading model and running inference…"):
            model = load_model()

        if model is None:
            st.stop()

        with st.spinner("Analysing tissue patterns…"):
            cc_t  = to_tensor(cc_proc)
            mlo_t = to_tensor(mlo_proc)

            with torch.no_grad():
                logits = model(cc_t, mlo_t)
                probs  = F.softmax(logits, dim=1)[0]

            pred_idx   = int(torch.argmax(probs).item())
            confidence = float(probs[pred_idx].item()) * 100

        st.divider()
        st.header(f"Result: {DENSITY_LABELS[pred_idx]}")
        st.info(CLINICAL_NOTES[pred_idx])
        st.metric("Confidence", f"{confidence:.1f}%")

        # Probability breakdown
        st.subheader("Probability Distribution")
        p_cols = st.columns(4)
        for i, (label, p) in enumerate(zip(DENSITY_LABELS, probs)):
            p_cols[i].metric(label.split(" (")[0], f"{float(p)*100:.1f}%")
            p_cols[i].progress(float(p))

        # GradCAM
        st.subheader("📍 GradCAM Explainability (CC View)")
        st.caption("Highlighted regions contributed most to the density prediction.")
        try:
            overlay = gradcam(model, cc_t, mlo_t, pred_idx, cc_proc)
            st.image(overlay, caption="GradCAM Overlay", width=500)
        except Exception as e:
            st.warning(f"GradCAM failed: {e}")

else:
    st.info("Upload both CC and MLO mammogram views in the sidebar to begin.")
