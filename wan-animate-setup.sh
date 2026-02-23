#!/bin/bash
set -e
source /venv/main/bin/activate

WORKSPACE=${WORKSPACE:-/workspace}
COMFYUI_DIR="${WORKSPACE}/ComfyUI"

echo "=== Wan Animate God Mode V3 Setup ==="

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

TEXT_ENCODERS=(
    "https://huggingface.co/f5aiteam/CLIP/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
)

CLIP_VISION=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
)

VAE_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
)

DIFFUSION_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_animate_14B_bf16.safetensors"
)

DETECTION_MODELS=(
    "https://huggingface.co/Wan-AI/Wan2.2-Animate-14B/resolve/main/process_checkpoint/det/yolov10m.onnx"
    "https://huggingface.co/yzd-v/DWPose/resolve/main/yolox_l.onnx"
    "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_model.onnx"
    "https://huggingface.co/Kijai/vitpose_comfy/resolve/main/onnx/vitpose_h_wholebody_data.bin"
)

DWPOSE_MODELS=(
    "https://huggingface.co/yzd-v/DWPose/resolve/main/dw-ll_ucoco_384.onnx"
    "https://huggingface.co/yzd-v/DWPose/resolve/main/dw-ll_ucoco_384_bs5.torchscript.pt"
)

SAM2_MODELS=(
    "https://huggingface.co/Kijai/sam2-safetensors/resolve/main/sam2.1_hiera_base_plus.safetensors"
)

UPSCALER_MODELS=(
    "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth"
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
provisioning_get_files "${COMFYUI_DIR}/models/dwpose" "${DWPOSE_MODELS[@]}"
provisioning_get_files "${COMFYUI_DIR}/models/sam2" "${SAM2_MODELS[@]}"
provisioning_get_files "${COMFYUI_DIR}/models/upscale_models" "${UPSCALER_MODELS[@]}"

echo ""
echo "=== Завантаження RIFE моделі ==="

RIFE_DIR="${COMFYUI_DIR}/models/rife"
mkdir -p "$RIFE_DIR"

if [[ ! -f "${RIFE_DIR}/rife49.pth" ]]; then
    echo "→ Завантаження rife49.pth..."
    wget ${HF_TOKEN:+--header="Authorization: Bearer $HF_TOKEN"} --content-disposition --show-progress -e dotbytes=4M \
        -O "${RIFE_DIR}/rife49.pth" \
        "https://huggingface.co/MachineDelusions/RIFE/resolve/main/rife49.pth" \
        || echo " [!] Помилка завантаження rife49.pth"
fi

echo ""
echo "=== Завантаження та перейменування LoRA моделей ==="

LORAS_DIR="${COMFYUI_DIR}/models/loras"
mkdir -p "$LORAS_DIR"

# I2V Lightx2v LoRA
if [[ ! -f "${LORAS_DIR}/i2v_lightx2v_low_noise_model.safetensors" ]]; then
    echo "→ Завантаження i2v_lightx2v_low_noise_model.safetensors..."
    wget ${HF_TOKEN:+--header="Authorization: Bearer $HF_TOKEN"} --content-disposition --show-progress -e dotbytes=4M \
        -O "${LORAS_DIR}/i2v_lightx2v_low_noise_model.safetensors" \
        "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors" \
        || echo " [!] Помилка завантаження i2v_lightx2v_low_noise_model"
fi

# T2V Lightx2v LoRA
if [[ ! -f "${LORAS_DIR}/t2v_lightx2v_low_noise_model.safetensors" ]]; then
    echo "→ Завантаження t2v_lightx2v_low_noise_model.safetensors..."
    wget ${HF_TOKEN:+--header="Authorization: Bearer $HF_TOKEN"} --content-disposition --show-progress -e dotbytes=4M \
        -O "${LORAS_DIR}/t2v_lightx2v_low_noise_model.safetensors" \
        "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Lightx2v/lightx2v_T2V_14B_cfg_step_distill_v2_lora_rank256_bf16.safetensors" \
        || echo " [!] Помилка завантаження t2v_lightx2v_low_noise_model"
fi

# Relight LoRA
if [[ ! -f "${LORAS_DIR}/wan2.2_animate_14B_relight_lora_bf16.safetensors" ]]; then
    echo "→ Завантаження wan2.2_animate_14B_relight_lora_bf16.safetensors..."
    wget ${HF_TOKEN:+--header="Authorization: Bearer $HF_TOKEN"} --content-disposition --show-progress -e dotbytes=4M \
        -P "${LORAS_DIR}" \
        "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_animate_14B_relight_lora_bf16.safetensors" \
        || echo " [!] Помилка завантаження relight lora"
fi

# Upscaler
UPSCALE_DIR="${COMFYUI_DIR}/models/upscale_models"
if [[ ! -f "${UPSCALE_DIR}/1xSkinContrast-SuperUltraCompact.pth" ]]; then
    echo "→ Завантаження 1xSkinContrast-SuperUltraCompact.pth..."
    wget ${HF_TOKEN:+--header="Authorization: Bearer $HF_TOKEN"} --content-disposition --show-progress -e dotbytes=4M \
        -O "${UPSCALE_DIR}/1xSkinContrast-SuperUltraCompact.pth" \
        "https://huggingface.co/risunobushi/1xSkinContrast/resolve/main/1xSkinContrast-SuperUltraCompact.pth" \
        || echo " [!] Помилка завантаження 1xSkinContrast"
fi

echo ""
echo "✅ Wan Animate God Mode V3 готовий!"
echo ""
echo "ПРИМІТКА: Для повної роботи workflow потрібно вручну додати 3 custom LoRA:"
echo "  - BreastsLoRA_ByHearmemanAI_HighNoise-000070.safetensors"
echo "  - Sadie01_LowNoise.safetensors"
echo "  - Sydney01_LowNoise.safetensors"
echo "Помістіть їх у: ${COMFYUI_DIR}/models/loras/"
echo ""
echo "Провізіонінг завершено. ComfyUI запуститься автоматично."
