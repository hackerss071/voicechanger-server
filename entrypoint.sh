#!/usr/bin/env bash
# Vast (and most GPU hosts) invoke a bare `entrypoint.sh` from $PATH as the container's
# command, overriding the image CMD. Baking this into /usr/local/bin makes the server
# auto-start no matter what launch mode / leftover args the host config has.
set -e
cd /opt/voice-changer/server
exec python MMVCServerSIO.py -p 8000 --https True --host 0.0.0.0 \
  --content_vec_500 pretrain/checkpoint_best_legacy_500.pt \
  --content_vec_500_onnx pretrain/content_vec_500.onnx --content_vec_500_onnx_on true \
  --hubert_base pretrain/hubert_base.pt \
  --hubert_base_jp pretrain/rinna_hubert_base_jp.pt \
  --hubert_soft pretrain/hubert/hubert-soft-0d54a1f4.pt \
  --nsf_hifigan pretrain/nsf_hifigan/model \
  --crepe_onnx_full pretrain/crepe_onnx_full.onnx \
  --crepe_onnx_tiny pretrain/crepe_onnx_tiny.onnx \
  --rmvpe pretrain/rmvpe.pt \
  --model_dir model_dir --samples samples.json
