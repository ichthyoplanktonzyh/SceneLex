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

## Conclusion

These runs do not support further prompt iteration as the next action. The same
failure signature appears across compound versus minimal motion, I2V versus T2V,
square versus landscape output, and with versus without an SDXL start image.
The current bottleneck is therefore the local Wan 2.2 5B / ComfyUI / Apple MPS
inference path (or its installed model/runtime combination), not the Director
translation alone. The Director prompt remains a valid model-independent input
for rerunning against a working local video backend or a stronger model later.
