{
  description = "Qwen3-TTS quick test environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Overlay that can be imported into NixOS
      overlay = final: prev: {
        qwen3-tts = self.packages.${final.system}.default;
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        python = pkgs.python312;
        
        pythonEnv = python.withPackages (ps: with ps; [
          pip
          soundfile
          torch
          torchaudio
        ]);

        # Qwen3-TTS script
        qwen3TtsScript = pkgs.writeShellScriptBin "qwen3-tts" ''
          set -e
          
          # Create a temporary directory for our demo
          TMPDIR=$(mktemp -d)
          cd "$TMPDIR"
          
          echo "Setting up Qwen3-TTS environment..."
          
          # Set up library path for PyTorch and other dependencies
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            pkgs.zlib
          ]}:$LD_LIBRARY_PATH"
          
          # Add sox and other audio tools to PATH
          export PATH="${pkgs.sox}/bin:${pkgs.ffmpeg}/bin:$PATH"
          
          # Create a temporary Python environment and install qwen-tts
          export TMPVENV="$TMPDIR/venv"
          ${pythonEnv}/bin/python -m venv "$TMPVENV" --system-site-packages
          source "$TMPVENV/bin/activate"
          pip install -q qwen-tts
          
          # Check if user provided training files
          if [ -f "$OLDPWD/training_audio.wav" ] && [ -f "$OLDPWD/transcript.txt" ]; then
            echo "Found training files! Using voice cloning mode..."
            MODE="clone"
            cp "$OLDPWD/training_audio.wav" ./
            cp "$OLDPWD/transcript.txt" ./
            
            # Get custom text if provided
            if [ -n "$1" ]; then
              CUSTOM_TEXT="$*"
              echo "Will generate: $CUSTOM_TEXT"
            else
              CUSTOM_TEXT="Hello from Qwen3-TTS! This is a quick test of the text to speech system using voice cloning."
              echo "No custom text provided. Using default message."
              echo "Tip: Run 'nix run . -- \"Your custom text here\"' to generate custom speech"
            fi
          else
            echo "No training files found. Using CustomVoice mode..."
            MODE="custom"
          fi
          
          # Create the appropriate test script based on mode
          if [ "$MODE" = "clone" ]; then
            export TARGET_TEXT="$CUSTOM_TEXT"
            cat > test_qwen3_tts.py << 'EOF'
import torch
import soundfile as sf
from qwen_tts import Qwen3TTSModel
import os

print("Loading Qwen3-TTS Base model for voice cloning...")

model = Qwen3TTSModel.from_pretrained(
    "Qwen/Qwen3-TTS-12Hz-1.7B-Base",
    device_map="cuda:0" if torch.cuda.is_available() else "cpu",
    dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32,
)

print("Reading training audio and transcript...")

# Read the transcript
with open("transcript.txt", "r") as f:
    ref_text = f.read().strip()

ref_audio = "training_audio.wav"

print(f"Reference text: {ref_text}")
print("\nGenerating speech with cloned voice...")

# The text to generate (from environment or default)
target_text = os.environ.get("TARGET_TEXT", "Hello from Qwen3-TTS! This is a quick test of the text to speech system using voice cloning.")

# Generate with cloned voice
wavs, sr = model.generate_voice_clone(
    text=target_text,
    language="English",  # Change this if your target text is in another language
    ref_audio=ref_audio,
    ref_text=ref_text,
)

output_file = "output_test.wav"
output_path = os.path.abspath(output_file)
sf.write(output_file, wavs[0], sr)
print(f"\nSuccess! Audio saved to: {output_path}")
print(f"Generated text: {target_text}")
EOF
          else
            cat > test_qwen3_tts.py << 'EOF'
import torch
import soundfile as sf
from qwen_tts import Qwen3TTSModel
import os

print("Loading Qwen3-TTS model (this may take a few minutes on first run)...")
print("Using the 0.6B CustomVoice model for faster testing...")

model = Qwen3TTSModel.from_pretrained(
    "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
    device_map="cuda:0" if torch.cuda.is_available() else "cpu",
    dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32,
)

print("\nGenerating speech from text...")

# Generate a simple test
wavs, sr = model.generate_custom_voice(
    text="Hello from Qwen3-TTS! This is a quick test of the text to speech system.",
    language="English",
    speaker="Ryan",
)

output_file = "output_test.wav"
output_path = os.path.abspath(output_file)
sf.write(output_file, wavs[0], sr)
print(f"\nSuccess! Audio saved to: {output_path}")
print(f"You can play it with: mpv {output_path}")
print(f"\nSupported speakers: {model.get_supported_speakers()}")
print(f"Supported languages: {model.get_supported_languages()}")
EOF
          fi

          # Run the test script
          python test_qwen3_tts.py
          
          # Copy output to current directory so user can keep it
          if [ -f output_test.wav ]; then
            cp output_test.wav "$OLDPWD/qwen3_tts_output.wav" 2>/dev/null || true
          fi
          
          echo ""
          echo "Demo files are in: $TMPDIR"
          echo "Output copied to: $OLDPWD/qwen3_tts_output.wav"
          echo ""
          echo "Would you like to play the audio? (y/n)"
          read -r response
          if [[ "$response" =~ ^[Yy]$ ]]; then
            ${pkgs.mpv}/bin/mpv "$TMPDIR/output_test.wav"
          fi
          
          echo ""
          echo "Press Enter to clean up temp files and exit..."
          read
          
          # Cleanup
          cd /
          rm -rf "$TMPDIR"
        '';

      in
      {
        packages.default = qwen3TtsScript;
        
        apps.default = {
          type = "app";
          program = "${qwen3TtsScript}/bin/qwen3-tts";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            pythonEnv
            pkgs.sox
            pkgs.mpv
            pkgs.ffmpeg
          ];
          
          shellHook = ''
            echo "Qwen3-TTS development environment"
            echo "=================================="
            echo ""
            echo "To install qwen-tts in a venv:"
            echo "  python -m venv venv"
            echo "  source venv/bin/activate"
            echo "  pip install qwen-tts"
            echo ""
            echo "For GPU support with FlashAttention2:"
            echo "  pip install flash-attn --no-build-isolation"
            echo ""
            echo "Quick start:"
            echo "  nix run"
          '';
        };
      }
    ) // {
      # Make overlay available at the top level
      overlays.default = overlay;
    };
}
