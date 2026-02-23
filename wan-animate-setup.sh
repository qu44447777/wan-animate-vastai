#!/bin/bash
set -euo pipefail
source /venv/main/bin/activate

WORKSPACE="${WORKSPACE:-/workspace}"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"

echo "=== Wan Animate God Mode V3 provisioning v2 ==="

# -----------------------------
# Custom nodes
# -----------------------------
NODES=(
  "https://github.com/kijai/ComfyUI-WanVideoWrapper"
  "https://github.com/kijai/ComfyUI-WanAnimatePreprocess"
  "https://github.com/chflame163/ComfyUI_LayerStyle"
  "https://github.com/yolain/ComfyUI-Easy-Use"
  "https://github.com/kijai/ComfyUI-KJNodes"
  "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
  "https://github.com/kijai/ComfyUI-segment-anything-2"
  "https://github.com/cubiq/ComfyUI_essentials"
  "https://github.com/fq393/ComfyUI-ZMG-Nodes"
  "https://github.com/rgthree/rgthree-comfy"
  "https://github.com/Fannovel16/comfyui_controlnet_aux"
  "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
  "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
  "https://github.com/ClownsharkBatwing/RES4LYF"
)

# -----------------------------
# Helpers
# -----------------------------
download_to() {
  # download_to "url" "output_path"
  local url="$1"
  local out="$2"
  mkdir -p "$(dirname "$out")"

  local auth=()
  if [[ -n "${HF_TOKEN:-}" && "$url" == *"huggingface.co"* ]]; then
    auth+=(--header="Authorization: Bearer ${HF_TOKEN}")
  elif [[ -n "${CIVITAI_TOKEN:-}" && "$url" == *"civitai.com"* ]]; then
    auth+=(--header="Authorization: Bearer ${CIVITAI_TOKEN}")
  fi

  if [[ -s "$out" ]]; then
    echo "✓ exists: $out"
    return 0
  fi

  echo "→ download: $url"
  wget "${auth[@]}" --show-progress -e dotbytes=4M -O "$out" "$url"

  if [[ ! -s "$out" ]]; then
    echo " [!] download failed or empty file: $out"
    return 1
  fi
}

check_required_file() {
  local f="$1"
  if [[ ! -s "$f" ]]; then
    echo " [!] MISSING required file: $f"
    return 1
  fi
  echo "✓ required: $f"
}

# -----------------------------
# Install / update custom nodes
# -----------------------------
mkdir -p "${COMFYUI_DIR}/custom_nodes"
cd "${COMFYUI_DIR}/custom_nodes"

for repo in "${NODES[@]}"; do
  dir="${repo##*/}"
  dir="${dir%.git}"
  path="./${dir}"

  if [[ -d "$path/.git" ]]; then
    echo "Updating: $dir"
    (cd "$path" && git pull --ff-only || { git fetch --all && git reset --hard origin/main; })
  else
    echo "Cloning: $dir"
    git clone --recursive "$repo" "$path"
  fi

  if [[ -f "$path/requirements.txt" ]]; then
    echo "Installing requirements for: $dir"
    pip install --no-cache-dir -r "$path/requirements.txt" || echo " [!] requirements failed for $dir"
  fi
done

# Extra runtime deps to reduce warnings/fallbacks
pip install --no-cache-dir opencv-contrib-python onnxruntime-gpu || true

# -----------------------------
# Download models (exact names)
# -----------------------------
echo "=== Downloading models ==="

# text encoder
download_to \
  "https://huggingface.co/f5aiteam/CLIP/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
  "${COMFYUI_DIR}/models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# clip vision
download_to \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
  "${COMFYUI_DIR}/models/clip_vision/clip_vision_h.safetensors"

# vae
download_to \
  "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
  "${COMFYUI_DIR}/models/vae/wan_2.1_vae.safetensors"

# diffusion models
download_to \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors" \
  "${COMFYUI_DIR}/models/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors"

download_to \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_animate_14B_bf16.safetensors" \
  "${COMFYUI_DIR}/models/diffusion_models/wan2.2_animate_14B_bf16.safetensors"

# loras
download_to \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors" \
  "${COMFYUI_DIR}/models/loras/i2v_lightx2v_low_noise_model.safetensors"

download_to \
  "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_T2V_14B_cfg_step_distill_v2_lora_rank256_bf16.safetensors" \
  "${COMFYUI_DIR}/models/loras/t2v_lightx2v_low_noise_model.safetensors"

download_to \
  "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_animate_14B_relight_lora_bf16.safetensors" \
  "${COMFYUI_DIR}/models/loras/wan2.2_animate_14B_relight_lora_bf16.safetensors"

# preprocess detection / dwpose
download_to \
  "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx" \
  "${COMFYUI_DIR}/models/detection/yolov10m.onnx"

download_to \
  "https://huggingface.co/yzd-v/DWPose/resolve/main/yolox_l.onnx" \
  "${COMFYUI_DIR}/models/detection/yolox_l.onnx"

download_to \
  "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx" \
  "${COMFYUI_DIR}/models/detection/vitpose_h_wholebody_model.onnx"

download_to \
  "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin" \
  "${COMFYUI_DIR}/models/detection/vitpose_h_wholebody_data.bin"

download_to \
  "https://huggingface.co/yzd-v/DWPose/resolve/main/dw-ll_ucoco_384.onnx" \
  "${COMFYUI_DIR}/models/dwpose/dw-ll_ucoco_384.onnx"

download_to \
  "https://huggingface.co/yzd-v/DWPose/resolve/main/dw-ll_ucoco_384_bs5.torchscript.pt" \
  "${COMFYUI_DIR}/models/dwpose/dw-ll_ucoco_384_bs5.torchscript.pt"

# SAM2
download_to \
  "https://huggingface.co/Kijai/sam2-safetensors/resolve/main/sam2.1_hiera_base_plus.safetensors" \
  "${COMFYUI_DIR}/models/sam2/sam2.1_hiera_base_plus.safetensors"

# optional alias (some nodes ask -fp16 filename)
if [[ -s "${COMFYUI_DIR}/models/sam2/sam2.1_hiera_base_plus.safetensors" ]]; then
  cp -f \
    "${COMFYUI_DIR}/models/sam2/sam2.1_hiera_base_plus.safetensors" \
    "${COMFYUI_DIR}/models/sam2/sam2.1_hiera_base_plus-fp16.safetensors"
fi

# upscalers
download_to \
  "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth" \
  "${COMFYUI_DIR}/models/upscale_models/4x-UltraSharp.pth"

download_to \
  "https://huggingface.co/risunobushi/1xSkinContrast/resolve/main/1xSkinContrast-SuperUltraCompact.pth" \
  "${COMFYUI_DIR}/models/upscale_models/1xSkinContrast-SuperUltraCompact.pth"

# -----------------------------
# RIFE (critical fix)
# -----------------------------
echo "=== RIFE fix ==="
download_to \
  "https://huggingface.co/MachineDelusions/RIFE/resolve/main/rife49.pth" \
  "${COMFYUI_DIR}/models/rife/rife49.pth"

mkdir -p "${COMFYUI_DIR}/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife"
cp -f \
  "${COMFYUI_DIR}/models/rife/rife49.pth" \
  "${COMFYUI_DIR}/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife/rife49.pth"

# -----------------------------
# Required file validation
# -----------------------------
echo "=== Validating required files ==="
missing=0

required_files=(
  "${COMFYUI_DIR}/models/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
  "${COMFYUI_DIR}/models/clip_vision/clip_vision_h.safetensors"
  "${COMFYUI_DIR}/models/vae/wan_2.1_vae.safetensors"
  "${COMFYUI_DIR}/models/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors"
  "${COMFYUI_DIR}/models/diffusion_models/wan2.2_animate_14B_bf16.safetensors"
  "${COMFYUI_DIR}/models/loras/i2v_lightx2v_low_noise_model.safetensors"
  "${COMFYUI_DIR}/models/loras/t2v_lightx2v_low_noise_model.safetensors"
  "${COMFYUI_DIR}/models/loras/wan2.2_animate_14B_relight_lora_bf16.safetensors"
  "${COMFYUI_DIR}/models/sam2/sam2.1_hiera_base_plus.safetensors"
  "${COMFYUI_DIR}/models/upscale_models/1xSkinContrast-SuperUltraCompact.pth"
  "${COMFYUI_DIR}/models/rife/rife49.pth"
  "${COMFYUI_DIR}/custom_nodes/ComfyUI-Frame-Interpolation/ckpts/rife/rife49.pth"
)

for f in "${required_files[@]}"; do
  if ! check_required_file "$f"; then
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo ""
  echo "❌ Provisioning finished with missing required files."
  exit 1
fi

echo ""
echo "✅ Provisioning completed successfully."
echo ""
echo "Manual private LoRAs still required:"
echo "  - BreastsLoRA_ByHearmemanAI_HighNoise-000070.safetensors"
echo "  - Sadie01_LowNoise.safetensors"
echo "  - Sydney01_LowNoise.safetensors"
echo "Place them into: ${COMFYUI_DIR}/models/loras"
echo ""
echo "Done."
