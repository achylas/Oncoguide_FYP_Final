import streamlit as st
import torch
import torch.nn as nn
import torch.nn.functional as F
import cv2
import numpy as np
import pydicom
from torchvision import models

# --- 1. SIAMESE MODEL ARCHITECTURE ---
def get_efficientnet():
    model = models.efficientnet_v2_s(weights=None)
    backbone = model.features
    feat_dim = 1280
    return backbone, feat_dim

class SiameseEfficientNet(nn.Module):
    def __init__(self, num_classes=4):
        super().__init__()
        self.backbone, self.feat_dim = get_efficientnet()
        self.pool = nn.AdaptiveAvgPool2d(1)
        self.classifier = nn.Sequential(
            nn.Linear(self.feat_dim * 2, 512),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(512, num_classes)
        )
        self.gradients = None

    def activations_hook(self, grad):
        self.gradients = grad

    def forward(self, cc, mlo):
        f1_acts = self.backbone(cc)
        f1_acts.register_hook(self.activations_hook) # For Grad-CAM
        f1 = self.pool(f1_acts).flatten(1)

        f2_acts = self.backbone(mlo)
        f2 = self.pool(f2_acts).flatten(1)
        return self.classifier(torch.cat([f1, f2], dim=1))

# --- 2. PREPROCESSING & ALIGNMENT ---
def full_preprocess_pipeline(img_array, target_size=1024):
    """Normalization, Cropping, and Orientation Alignment (is_right)."""
    # Fix the range error by converting to uint8 immediately
    img = img_array.astype(np.float32)
    img = (img - np.min(img)) / (np.max(img) - np.min(img) + 1e-7)
    img = (img * 255).astype(np.uint8)
    
    # Crop Breast
    _, thresh = cv2.threshold(img, 5, 255, cv2.THRESH_BINARY)
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if contours:
        cnt = max(contours, key=cv2.contourArea)
        x, y, w, h = cv2.boundingRect(cnt)
        img = img[y:y+h, x:x+w]
        
    # Resize and Align (is_right logic)
    h, w = img.shape
    scale = target_size / max(h, w)
    new_w, new_h = int(w * scale), int(h * scale)
    resized = cv2.resize(img, (new_w, new_h))
    
    canvas = np.zeros((target_size, target_size), dtype=np.uint8)
    
    # Orientation Check
    left_sum = np.sum(img[:, :w//2])
    right_sum = np.sum(img[:, w//2:])
    is_right = right_sum > left_sum
    
    dy = (target_size - new_h) // 2
    dx = (target_size - new_w) if is_right else 0 
    canvas[dy:dy+new_h, dx:dx+new_w] = resized
    
    # CLAHE
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    return clahe.apply(canvas)

# --- 3. EXPLAINABILITY ENGINE ---
def generate_gradcam(model, cc_t, mlo_t, target_class):
    model.eval()
    output = model(cc_t, mlo_t)
    model.zero_grad()
    output[0, target_class].backward()
    
    grads = model.gradients
    pooled_grads = torch.mean(grads, dim=[0, 2, 3])
    activations = model.backbone(cc_t).detach()
    
    for i in range(activations.shape[1]):
        activations[:, i, :, :] *= pooled_grads[i]
    
    heatmap = torch.mean(activations, dim=1).squeeze()
    heatmap = np.maximum(heatmap.cpu(), 0)
    heatmap /= (torch.max(heatmap) + 1e-7)
    return heatmap.numpy()

def overlay_heatmap(heatmap, original_img):
    heatmap = cv2.resize(heatmap, (original_img.shape[1], original_img.shape[0]))
    heatmap = np.uint8(255 * heatmap)
    heatmap = cv2.applyColorMap(heatmap, cv2.COLORMAP_JET)
    return cv2.addWeighted(cv2.cvtColor(original_img, cv2.COLOR_GRAY2RGB), 0.6, heatmap, 0.4, 0)

# --- 4. DATA LOADING ---
def load_image_input(f):
    if f.name.lower().endswith('.dcm'):
        ds = pydicom.dcmread(f)
        img = ds.pixel_array.astype(np.float32)
        if getattr(ds, "PhotometricInterpretation", "") == "MONOCHROME1":
            img = np.max(img) - img
    else:
        file_bytes = np.asarray(bytearray(f.read()), dtype=np.uint8)
        img = cv2.imdecode(file_bytes, cv2.IMREAD_GRAYSCALE).astype(np.float32)
    
    # Normalize to uint8 for Streamlit display safety
    img = (img - np.min(img)) / (np.max(img) - np.min(img) + 1e-7)
    return (img * 255).astype(np.uint8)

# --- 5. STREAMLIT UI ---
st.set_page_config(page_title="Explainable Breast Density AI", layout="wide")
st.title("Breast Density Siamese Classification & Explainability")

st.sidebar.header("Data Upload")
cc_file = st.sidebar.file_uploader("Upload CC View", type=['dcm', 'png', 'jpg'])
mlo_file = st.sidebar.file_uploader("Upload MLO View", type=['dcm', 'png', 'jpg'])

if cc_file and mlo_file:
    # 1. Load & Preprocess
    cc_raw = load_image_input(cc_file)
    mlo_raw = load_image_input(mlo_file)
    cc_proc = full_preprocess_pipeline(cc_raw)
    mlo_proc = full_preprocess_pipeline(mlo_raw)

    # 2. Display Files and Pipeline
    st.write(f"### 📋 Files: `{cc_file.name}` and `{mlo_file.name}`")
    
    col_cc, col_mlo = st.columns(2)
    with col_cc:
        st.image(cc_raw, caption="Original CC", use_container_width=True)
        st.image(cc_proc, caption="Processed & Aligned CC", use_container_width=True)
    with col_mlo:
        st.image(mlo_raw, caption="Original MLO", use_container_width=True)
        st.image(mlo_proc, caption="Processed & Aligned MLO", use_container_width=True)

    if st.button("🚀 Run Diagnostic Analysis"):
        with st.spinner("Analyzing tissue patterns..."):
            # Model Setup
            model = SiameseEfficientNet(num_classes=4)
            try:
                model.load_state_dict(torch.load("density_model.pth", map_location="cpu"))
                model.eval()

                # Tensors
                def to_t(img):
                    img = cv2.resize(img, (384, 384))
                    img = np.stack([img, img, img], axis=-1)
                    return torch.from_numpy(img).permute(2, 0, 1).float().unsqueeze(0) / 255.0

                cc_t, mlo_t = to_t(cc_proc), to_t(mlo_proc)
                
                # Predict
                output = model(cc_t, mlo_t)
                probs = F.softmax(output, dim=1)[0]
                conf, pred = torch.max(probs, 0)
                
                labels = ["Density A (Fatty)", "Density B (Scattered)", 
                          "Density C (Heterogeneous)", "Density D (Extremely Dense)"]
                
                st.divider()
                st.header(f"Result: {labels[pred.item()]}")
                
                # Explainability Section
                cc_hm = generate_gradcam(model, cc_t, mlo_t, pred.item())
                cc_viz = overlay_heatmap(cc_hm, cc_proc)
                
                st.subheader("📍 Explainability Heatmap (CC View)")
                st.info("The heatmap shows which regions contributed most to the density score.")
                st.image(cc_viz, caption="Grad-CAM Visualization", width=600)

                # Class breakdown
                st.write("#### Probability Distribution")
                p_cols = st.columns(4)
                for i, (label, p) in enumerate(zip(labels, probs)):
                    p_cols[i].metric(label.split(" (")[0], f"{p.item()*100:.1f}%")
                    p_cols[i].progress(float(p.item()))
                
            except FileNotFoundError:
                st.error("Weights file 'best_model.pth' not found in current directory.")