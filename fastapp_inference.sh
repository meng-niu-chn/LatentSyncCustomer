#!/bin/bash

# 接收命令行参数
video_path=$1
audio_path=$2
video_out_path=$3

# 运行 Python 脚本
python -m scripts.inference \
    --unet_config_path "configs/unet/second_stage.yaml" \
    --inference_ckpt_path "checkpoints/latentsync_unet.pt" \
    --guidance_scale 1.0 \
    --video_path "$video_path" \
    --audio_path "$audio_path" \
    --video_out_path "$video_out_path"