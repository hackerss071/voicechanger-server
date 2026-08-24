# Pre-baked w-okada voice-changer server for real-time female RVC on a rented GPU.
# Everything (w-okada + all deps + the full pretrain weight set ~1GB) is baked in, so a
# fresh Vast/RunPod pod just PULLS this image and the server auto-starts — no per-session
# install and no per-session download. You only upload your RVC model (Bengali_Female.pth)
# once via the UI (a ~54MB, few-second upload).
#
# Base = the environment w-okada's pinned requirements were written for (Python 3.10,
# torch 2.1.2, CUDA 12.1, cuDNN 8) — so the pins "just work" and it runs on an RTX 3090.
FROM pytorch/pytorch:2.1.2-cuda12.1-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive PIP_ROOT_USER_ACTION=ignore PIP_NO_CACHE_DIR=1

RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
      git curl ca-certificates ffmpeg libportaudio2 build-essential cmake && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone --depth 1 https://github.com/w-okada/voice-changer.git
WORKDIR /opt/voice-changer/server

# Deps: keep the image's torch 2.1.2 (drop the torch/torchaudio pins), drop the dead
# onnxruntime-gpu==1.13.1 pin and use CPU onnxruntime instead (the ONNX content-vec
# embedder runs fine on the pod's CPU; the RVC model itself runs on the GPU). fairseq is
# deliberately NOT installed — it isn't in requirements and the server only imports it if a
# fairseq (hubert) embedder is selected, which we don't (content_vec_500_onnx_on=true).
RUN pip install "pip<24.1" && \
    sed -i '/^torch==/d;/^torchaudio==/d;/^onnxruntime-gpu/d' requirements.txt && \
    pip install requests onnxruntime pyworld colorama nest_asyncio && \
    pip install -r requirements.txt

# Bake the FULL pretrain weight set (~1GB: hubert, rinna-hubert, hubert-soft, nsf_hifigan,
# crepe, content-vec onnx, rmvpe, samples). w-okada's WeightDownloader raises unless the
# whole set is present, so we run the server once (CPU, no GPU at build) which downloads
# everything, wait for its "ready" marker, then stop. Verify key files landed.
RUN set -e; \
    ( python MMVCServerSIO.py -p 8000 --https True --host 127.0.0.1 \
        --content_vec_500 pretrain/checkpoint_best_legacy_500.pt \
        --content_vec_500_onnx pretrain/content_vec_500.onnx --content_vec_500_onnx_on true \
        --hubert_base pretrain/hubert_base.pt \
        --hubert_base_jp pretrain/rinna_hubert_base_jp.pt \
        --hubert_soft pretrain/hubert/hubert-soft-0d54a1f4.pt \
        --nsf_hifigan pretrain/nsf_hifigan/model \
        --crepe_onnx_full pretrain/crepe_onnx_full.onnx \
        --crepe_onnx_tiny pretrain/crepe_onnx_tiny.onnx \
        --rmvpe pretrain/rmvpe.pt \
        --model_dir model_dir --samples samples.json > /tmp/warm.log 2>&1 & echo $! > /tmp/pid ); \
    for i in $(seq 1 120); do grep -q "MMVC_SocketIOApp initializing... done" /tmp/warm.log && break; sleep 4; done; \
    kill -9 "$(cat /tmp/pid)" 2>/dev/null || true; \
    echo "----- warm.log tail -----"; tail -30 /tmp/warm.log; echo "-------------------------"; \
    test -f pretrain/rmvpe.pt && test -f pretrain/hubert_base.pt && test -f pretrain/content_vec_500.onnx

# Bake the entrypoint Vast execs (a bare "entrypoint.sh" found via $PATH), placed LAST so the
# big apt/pip/pretrain layers above keep identical hashes (cached on the host → fast re-pull).
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8000

# Auto-start on 0.0.0.0 (REQUIRED — else Vast's docker port-forward can't reach the server).
CMD ["python", "MMVCServerSIO.py", "-p", "8000", "--https", "True", "--host", "0.0.0.0", \
     "--content_vec_500", "pretrain/checkpoint_best_legacy_500.pt", \
     "--content_vec_500_onnx", "pretrain/content_vec_500.onnx", "--content_vec_500_onnx_on", "true", \
     "--hubert_base", "pretrain/hubert_base.pt", \
     "--hubert_base_jp", "pretrain/rinna_hubert_base_jp.pt", \
     "--hubert_soft", "pretrain/hubert/hubert-soft-0d54a1f4.pt", \
     "--nsf_hifigan", "pretrain/nsf_hifigan/model", \
     "--crepe_onnx_full", "pretrain/crepe_onnx_full.onnx", \
     "--crepe_onnx_tiny", "pretrain/crepe_onnx_tiny.onnx", \
     "--rmvpe", "pretrain/rmvpe.pt", \
     "--model_dir", "model_dir", "--samples", "samples.json"]
