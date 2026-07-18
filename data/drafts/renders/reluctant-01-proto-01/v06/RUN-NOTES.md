# reluctant v06 — local ComfyUI run notes

Date: 2026-07-18  
ComfyUI: 0.28.0, Apple MPS  
Image checkpoint: `disneyrealcartoonmix_v10.safetensors`  
Video model: `wan2.2_ti2v_5B_fp16.safetensors`  
Text encoder: `umt5_xxl_fp8_e4m3fn_scaled.safetensors`  
VAE: `wan2.2_vae.safetensors`

## Director intent

The source SceneSpec was not changed. The production target was beats 3–5:
the boy pauses and slumps, makes minimal contact with the garbage bag, moves
slowly toward the task, and looks back at the game. The full three-clip plan is
stored in `../../../director/reluctant-01-proto-01/v01/director-prompt.yaml`.

## Image attempts

1. `clip-02-keyframe.png` — rejected. The image model changed the teenage boy
   into a girl with a backpack and omitted the garbage bag.
2. `clip-02-keyframe-b.png` — accepted as an I2V experiment input. It produced
   a teenage boy at the front door, a large black garbage bag, and readable
   reluctance, although the bag remained beside him rather than in his hand.

`keyframe-workflow-api.json` contains the second keyframe workflow.

## Video attempts

### Attempt A — image-to-video, compound movement

- Output: `reluctant-clip-02.mp4`
- ComfyUI prompt id: `55949d17-0805-4b97-8447-ec7d3871226d`
- 512×512, 49 frames, 16 fps, 20 steps, CFG 5, UniPC/simple, shift 8
- Motion: hesitate, lift bag, take a slow step, look back
- Result: rejected. The first frame was coherent, then the body and bag
  developed severe trails, color separation, and structural deformation.
- Total ComfyUI execution time: about 11 minutes.

### Attempt B — image-to-video, minimal movement

- Output: `reluctant-clip-02-b.mp4`
- ComfyUI prompt id: `61b67d18-f52b-4663-9aeb-3ecba16c2f23`
- 512×512, 33 frames, 16 fps, 20 steps, CFG 5, UniPC/simple, shift 8
- Motion: eye movement, shoulder slump, sigh, slight reach, look back
- Result: rejected. Red/white striping, broken anatomy, and posterization were
  even stronger despite the much smaller requested motion.
- Total ComfyUI execution time: 372.15 seconds.

### Attempt C — text-to-video isolation run

- Output: `reluctant-clip-02-t2v.mp4`
- ComfyUI prompt id: `83f5e4dc-42cb-42c9-80b4-538bc92bdfa1`
- 832×480, 33 frames, 16 fps, 20 steps, CFG 5, UniPC/simple, shift 8
- No start image; native landscape generation with a simplified scene and motion
- Result: rejected. It produced the same saturated color separation, blur, and
  malformed character from the first frame onward.
- Total ComfyUI execution time: 588.78 seconds.

`wan-workflow-api.json` contains Attempt C, the final isolation workflow.

### Attempt D — fp16 text encoder isolation (2026-07-18/19)

- Output: `reluctant_v06_clip02_t2v_fp16test_00001_.mp4` / `_00002_.mp4`
- Same T2V config as Attempt C, only the CLIP loader swapped from
  `umt5_xxl_fp8_e4m3fn_scaled.safetensors` to `umt5_xxl_fp16.safetensors`
  (`wan-workflow-api.json`).
- Hypothesis: Apple MPS does not support Float8_e4m3fn (documented ComfyUI
  issues #9255/#9263), so the fp8 text encoder was silently producing bad
  conditioning.
- Result: rejected. Identical failure signature to Attempt C (frame sizes
  byte-identical on a same-seed rerun, confirming determinism, not a fluke).
  707s and 601s across two runs. **Hypothesis disproved.**

### Attempt E — GGUF quantization isolation

- Output: `reluctant_v06_clip02_t2v_ggufQ8test_00001_.mp4`
- Installed `city96/ComfyUI-GGUF`; swapped both the UNET
  (`Wan2.2-TI2V-5B-Q8_0.gguf`, QuantStack) and the text encoder
  (`umt5-xxl-encoder-Q8_0.gguf`, city96) to GGUF Q8_0
  (`wan-workflow-api-gguf.json`). VAE unchanged
  (`wan2.2_vae.safetensors`, correct for TI2V-5B — the 14B A14B variants
  reuse the Wan2.1 VAE, TI2V-5B has its own; a separate community workflow
  using `wan2.2_i2v_*_14B` confirmed this pairing convention independently).
- Rationale: an external report (M1 Max 64GB, GGUF Q4_K_S/Q8_0) produced a
  working Wan2.2 video via ComfyUI-GGUF, avoiding the standard safetensors
  MPS path entirely.
- Result: rejected. Same failure signature (blur, color separation, banding).
  732s. **Hypothesis disproved — the GGUF code path does not avoid the bug
  on this ComfyUI 0.28.0 / macOS 26.5.1 / M1 Max combination.**

### Attempt F — VAE decode isolation (`--cpu-vae`)

- Output: `reluctant_v06_clip02_t2v_cpuvaetest_00001_.mp4`
- Restarted ComfyUI with `--cpu-vae` (VAE decode fully on CPU, bypassing MPS,
  bfloat16, and the "split attention in VAE" fallback all at once). Same
  fp16 T2V workflow as Attempt D, same seed.
- Rationale: across Attempts C/D/E, the VAE was the only component held
  constant (same file, same 1344.09 MB footprint, same
  `Using split attention in VAE` / `dtype: torch.bfloat16` log lines every
  run) while UNET/CLIP precision varied three times with no change in
  output — process of elimination pointed at VAE decode as the last
  untested stage.
- Result: rejected. Output pixel-identical in character to Attempts C/D/E.
  **Hypothesis disproved — VAE decode location/precision is not the cause.**

## Conclusion (revised 2026-07-19)

Five independent variables have now been tested and eliminated one at a time,
each holding all other components fixed:

1. Text encoder precision — fp8 vs fp16 vs GGUF Q8_0 (Attempts C/D/E)
2. UNET quantization — fp16 safetensors vs GGUF Q8_0 (Attempts C/E)
3. VAE decode device/precision — MPS bfloat16 (split attention) vs CPU
   fp32 (Attempts C–E vs F)
4. Motion amount — compound vs minimal (Attempts A/B)
5. Generation mode / aspect ratio — I2V square vs T2V landscape, with and
   without an SDXL start image (Attempts A–C)

All five produced the same failure signature: severe blur, color
separation/channel bleeding, and horizontal banding, present from the first
frame onward. Since varying every model file and every axis of the pipeline
independently produced no change, the corruption is not attributable to any
single swappable component. It most likely originates in the UNET diffusion/
sampling loop itself on this specific `ComfyUI 0.28.0 + PyTorch (nightly,
2.12.0.dev20260313) + Apple MPS` combination — plausibly a numerical or
attention-kernel bug specific to how Wan2.2's architecture (3D/temporal
attention, RoPE) is executed on MPS — rather than any configuration choice
documented here. Confirming the exact operator responsible would require
kernel-level debugging, which was judged not worth the investment once the
project's video-generation strategy moved to cloud APIs (see
`.planning/STATE.md`). The Director prompt remains a valid model-independent
input for resubmission against a cloud video backend or any future working
local backend.
