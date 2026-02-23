#!/bin/bash
set -e
source /venv/main/bin/activate

WORKSPACE=${WORKSPACE:-/workspace}
COMFYUI_DIR="${WORKSPACE}/ComfyUI"

echo "=== Wan Animate God Mode V3 Setup ==="

APT_PACKAGES=()
PIP_PACKAGES=()

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
)

# Text Encoders (CLIP)
TEXT_ENCODERS=(
    "https://huggingface.co/f5aiteam/CLIP/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
)

# CLIP Vision
CLIP_VISION=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
)

# VAE
VAE_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
)

# Diffusion Models
DIFFUSION_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22Animate/wan2.2_animate_14B_bf16.safetensors"
)

# Detection Models
DETECTION_MODELS=(
    "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"
    "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolox_l.onnx"
    "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"
    "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"
)

# SAM2
SAM2_MODELS=(
    "https://huggingface.co/Kijai/sam2-safetensors/resolve/main/sam2.1_hiera_base_plus.safetensors"
)

# LoRAs
LORAS=(
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1_low_noise.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Relight/wan2.2_animate_14B_relight_lora_bf16.safetensors"
)

# RIFE
RIFE_MODELS=(
    "https://github.com/hzwer/Practical-RIFE/releases/download/v4.9/rife49.pth"
)

# Upscalers
UPSCALER_MODELS=(
    "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth"
    "https://huggingface.co/Kijai/upscaler-models/resolve/main/1xSkinContrast-SuperUltraCompact.pth"
)

# DWPose
DWPOSE_MODELS=(
    "https://huggingface.co/yzd-v/DWPose/resolve/main/dw-ll_ucoco_384.onnx"
)

function provisioning_get_nodes() {
    mkdir -p "${COMFYUI_DIR}/custom_nodes"
    cd "${COMFYUI_DIR}/custom_nodes"

    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        dir="${dir%.git}"
        path="./${dir}"

        if [[ -d "$path" ]]; then
            echo "Оновлення: $dir"
            (cd "$path" && git pull --ff-only 2>/dev/null || { git fetch && git reset --hard origin/main; })
        else
            echo "Клонування: $dir"
            git clone "$repo" "$path" --recursive || echo " [!] Помилка клонування: $repo"
        fi

        requirements="${path}/requirements.txt"
        if [[ -f "$requirements" ]]; then
            echo "Встановлення залежностей для $dir..."
            pip install --no-cache-dir -r "$requirements" || echo " [!] Помилка встановлення залежностей для $dir"
        fi
    done
}

function provisioning_get_files() {
    if [[ $# -lt 2 ]]; then return; fi
    local dir="$1"
    shift
    local files=("$@")

    mkdir -p "$dir"
    echo ""
    echo "Завантаження ${#files[@]} файл(ів) → $dir..."

    for url in "${files[@]}"; do
        echo "→ $url"
        local auth_header=""
        if [[ -n "$HF_TOKEN" && "$url" =~ huggingface\.co ]]; then
            auth_header="--header=Authorization: Bearer $HF_TOKEN"
        elif [[ -n "$CIVITAI_TOKEN" && "$url" =~ civitai\.com ]]; then
            auth_header="--header=Authorization: Bearer $CIVITAI_TOKEN"
        fi

        wget $auth_header -nc --content-disposition --show-progress -e dotbytes=4M -P "$dir" "$url" || echo " [!] Помилка завантаження: $url"
        echo ""
    done
}

echo ""
echo "=== Встановлення Custom Nodes ==="
provisioning_get_nodes

echo ""
echo "=== Завантаження моделей ==="

provisioning_get_files "${COMFYUI_DIR}/models/text_encoders" "${TEXT_ENCODERS[@]}"
provisioning_get_files "${COMFYUI_DIR}/models/clip_vision" "${CLIP_VISION[@]}"
provisioning_get_files "${COMFYUI_DIR}/models/vae" "${VAE_MODELS[@]}"
provisioning_get_files "${COMFYUI_DIR}/models/diffusion_models" "${DIFFUSION_MODELS[@]}"
provisioning_get_files "${COMFYUI_DIR}/models/detection" "${DETECTION_MODELS[@]}"
provisioning_get_files "${COMFYUI_DIR}/models/sam2" "${SAM2_MODELS[@]}"
provisioning_get_files "${COMFYUI_DIR}/models/loras" "${LORAS[@]}"
provisioning_get_files "${COMFYUI_DIR}/models/rife" "${RIFE_MODELS[@]}"
provisioning_get_files "${COMFYUI_DIR}/models/upscale_models" "${UPSCALER_MODELS[@]}"
provisioning_get_files "${COMFYUI_DIR}/models/dwpose" "${DWPOSE_MODELS[@]}"

echo ""
echo "✅ Wan Animate God Mode V3 готовий!"
echo "Провізіонінг завершено. ComfyUI запуститься автоматично."
