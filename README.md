# Qwen3-TTS Nix Flake

Qwen3-TTS flake for NixOS with voice cloning support.

## Quick Start

### CustomVoice Mode (Default)

Just run:

```bash
nix run . -- "Your custom text here"
```

### Voice Cloning Mode

To clone a voice, create two files in the same directory as the flake:

1. **`training_audio.wav`** - A 3+ second audio clip of the voice you want to clone
2. **`transcript.txt`** - The exact text spoken in the training audio

```bash
nix run . -- "Your custom text here"
```

This will:
1. ✅ Load the 1.7B Base model (better quality for cloning)
2. ✅ Use your training audio and transcript
3. ✅ Generate speech with your custom text in the cloned voice
4. ✅ Save it as `qwen3_tts_output.wav` in your current directory

## GPU Support

If you have a CUDA-compatible GPU, the script will automatically use it. For the best performance, you may want to install FlashAttention2 manually:

```bash
nix develop
python -m venv venv
source venv/bin/activate
pip install qwen-tts
pip install flash-attn --no-build-isolation
```

## Development Shell

Enter a development environment with all tools:

```bash
nix develop
python -m venv venv
source venv/bin/activate
```

Then you can install qwen-tts and experiment:

```bash
pip install qwen-tts
python
```

## Available Models

The demo uses the 0.6B model for speed, but you can modify the flake to use any model:

- `Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice` (fastest, demo default)
- `Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice` (better quality)
- `Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign` (with instruction control)
- `Qwen/Qwen3-TTS-12Hz-1.7B-Base` (for voice cloning)

## Example Usage

```python
import torch
import soundfile as sf
from qwen_tts import Qwen3TTSModel

model = Qwen3TTSModel.from_pretrained(
    "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
    device_map="cuda:0",  # or "cpu"
    dtype=torch.bfloat16,
)

wavs, sr = model.generate_custom_voice(
    text="Your text here",
    language="English",
    speaker="Ryan",
)

sf.write("output.wav", wavs[0], sr)
```

## Supported Speakers (CustomVoice models)

- **Vivian** - Bright Chinese female voice
- **Serena** - Warm Chinese female voice  
- **Uncle_Fu** - Seasoned Chinese male voice
- **Dylan** - Beijing male voice
- **Eric** - Chengdu male voice
- **Ryan** - Dynamic English male voice
- **Aiden** - American English male voice
- **Ono_Anna** - Japanese female voice
- **Sohee** - Korean female voice

## Supported Languages

Chinese, English, Japanese, Korean, German, French, Russian, Portuguese, Spanish, Italian

## Notes

- First run will download model weights (can take a few minutes)
- Models are cached in `~/.cache/huggingface/`
- CPU inference works but is slower than GPU

## NixOS Integration

You can add this flake as an overlay to your NixOS system to make `qwen3-tts` available system-wide.

In your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    qwen3-tts.url = "github:ilioscio/qwen3-tts-flake";
  };

  outputs = { self, nixpkgs, qwen3-tts, ... }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Add the overlay
        { nixpkgs.overlays = [ qwen3-tts.overlays.default ]; }
        
        # Then use it in your config
        ({ pkgs, ... }: {
          environment.systemPackages = [
            pkgs.qwen3-tts
          ];
        })
      ];
    };
  };
}
```

After rebuilding your system, you can run `qwen3-tts` from anywhere!

### Usage Examples

```bash
# Basic usage with default test message
qwen3-tts

# Voice cloning with custom text (requires training_audio.wav and transcript.txt in current dir)
qwen3-tts "Say anything you want in the cloned voice"

# The output is always saved as qwen3_tts_output.wav in your current directory
```
