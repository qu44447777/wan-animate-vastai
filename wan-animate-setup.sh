#!/bin/bash
set -e

WORKSPACE=${WORKSPACE:-/workspace}
COMFYUI_DIR="${WORKSPACE}/ComfyUI"

echo "=== Wan Animate God Mode V3 Setup ==="

# Глобальні залежності
echo ""
echo "=== Встановлення глобальних залежностей ==="
pip install opencv-python opencv-contrib-python accelerate imageio-ffmpeg

# Custom nodes
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

# Text Encoders (CLIP для Wan)
TEXT_ENCODERS=(
    "https://huggingface.co/f5aiteam/CLIP/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
)

# CLIP Vision моделі
CLIP_VISION=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
)

# VAE моделі
VAE_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
)

# Diffusion моделі (Wan UNET моделі)
DIFFUSION_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan22Animate/wan2.2_animate_14B_bf16.safetensors"
)

# Detection моделі (ONNX)
DETECTION_MODELS=(
    "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"
    "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolox_l.onnx"
    "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"
    "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"
)

# SAM2 моделі
SAM2_MODELS=(
    "https://huggingface.co/Kijai/sam2-safetensors/resolve/main/sam2.1_hiera_base_plus.safetensors"
)

# LoRA моделі
LORAS=(
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1_low_noise.safetensors"
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Relight/wan2.2_animate_14B_relight_lora_bf16.safetensors"
)

# RIFE моделі
RIFE_MODELS=(
    "https://github.com/hzwer/Practical-RIFE/releases/download/v4.9/rife49.pth"
)

# Upscaler моделі
UPSCALER_MODELS=(
    "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth"
    "https://huggingface.co/Kijai/upscaler-models/resolve/main/1xSkinContrast-SuperUltraCompact.pth"
)

# DWPose моделі
DWPOSE_MODELS=(
    "https://huggingface.co/yzd-v/DWPose/resolve/main/dw-ll_ucoco_384.onnx"
)

# Функція для клонування/оновлення custom nodes
provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${COMFYUI_DIR}/custom_nodes/$(basename "${repo}" .git)"
        if [[ -d "$dir" ]]; then
            echo "Оновлення: $repo"
            (cd "$dir" && git pull)
        else
            echo "Клонування: $repo"
            git clone "${repo}" "$dir" || echo "⚠ Помилка клонування: $repo"
        fi
        
        if [[ -f "${dir}/requirements.txt" ]]; then
            echo "Встановлення залежностей для $(basename "$dir")"
            pip install -r "${dir}/requirements.txt" || echo "⚠ Помилка встановлення залежностей"
        fi
    done
}

# Функція для завантаження файлів
provisioning_get_files() {
    local dest_dir="$1"
    shift
    local url_list=("$@")
    
    local count=${#url_list[@]}
    echo ""
    echo "Завантаження ${count} файл(ів) → ${dest_dir}..."
    
    mkdir -p "${dest_dir}"
    
    for url in "${url_list[@]}"; do
        local filename=$(basename "${url%%\?*}")
        local filepath="${dest_dir}/${filename}"
        
        if [[ -f "$filepath" ]]; then
            echo "✓ Вже існує: ${filename}"
            continue
        fi
        
        echo "→ ${url}"
        if wget -q --show-progress -O "${filepath}" "${url}"; then
            echo "✓ Завантажено: ${filename}"
        else
            echo " [!] Помилка завантаження: ${url}"
        fi
    done
}

# Встановлення custom nodes
echo ""
echo "=== Встановлення Custom Nodes ==="
provisioning_get_nodes

# Завантаження моделей
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
