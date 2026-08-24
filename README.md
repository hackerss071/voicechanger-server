# voicechanger-server — pre-baked real-time voice-changer image

A ready-to-run Docker image of the [w-okada voice-changer](https://github.com/w-okada/voice-changer)
server with **all dependencies + the full pretrain weight set baked in**. Rent a GPU,
point it at this image, and the server auto-starts — no per-session install, no downloads.

Only your RVC voice model (e.g. `Bengali_Female.pth`, ~54 MB) is uploaded once per session
in the web UI.

This is generic infrastructure — it contains **no personal data**: just public w-okada code
and public HuggingFace pretrain weights.

---

## One-time: publish the image (via GitHub Actions → GHCR)

1. Create a **new public GitHub repo** named `voicechanger-server`.
2. Put these two files in it (keep the paths):
   - `Dockerfile`
   - `.github/workflows/build.yml`
3. Push to `main`. The **Actions** tab will build the image (~15–20 min) and push it to
   `ghcr.io/<your-username>/voicechanger-server:latest`.
4. Make the package **public** so the GPU host can pull it without a login:
   your GitHub profile → **Packages** → `voicechanger-server` → **Package settings** →
   **Change visibility** → **Public**.

Re-run anytime from the **Actions** tab → *build-image* → **Run workflow**.

---

## Each session: rent + use (~3–4 min, no setup)

1. **Vast.ai** → rent an **RTX 3090** (or similar), Location Asia (India/Malaysia/…):
   - **Image:** `ghcr.io/<your-username>/voicechanger-server:latest`
   - **Docker option:** `-p 8000:8000`
   - Launch mode: *Docker ENTRYPOINT / Args* (the image auto-runs the server; no Jupyter needed)
2. Wait for the pod to pull the image and show **running** (~2–3 min).
3. Find the external port: on the instance, `VAST_TCP_PORT_8000` (or click the IP → port map
   for `8000`). Open **`https://<ip>:<port>/`** in Chrome/Brave (type `https://` explicitly),
   accept the self-signed warning.
4. In the UI:
   - **GPU** = the RTX 3090 (not `cpu`)
   - **edit** a model slot → upload `Bengali_Female.pth`, **Tune +12**, select it
   - **input** = your real mic, **output** = VoiceChangerSink, **F0** = rmvpe
   - press **start**
5. On the laptop: browser/WhatsApp mic = **"Voice Changer Mic"** → speak.
6. **When done: DESTROY the pod** (Stop is unreliable on Vast — the GPU can get taken).
   Billing stops; next time just rent again with this image.

## Notes
- The server binds `0.0.0.0` (required for the pod's port-forward to reach it).
- To also bake the model in (skip the per-session upload), add a `COPY` + a startup
  registration step later — kept out of the base image so it stays generic/public.
