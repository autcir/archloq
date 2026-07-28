#!/usr/bin/env bash
set -euo pipefail

install -d "$HOME/.local/bin" "$HOME/.local/share/applications"

cat >"$HOME/.local/bin/loq-safe-env" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Prefer Intel/Mesa and avoid selecting NVIDIA through GLVND/Vulkan.
export __GLX_VENDOR_LIBRARY_NAME=mesa
export __NV_PRIME_RENDER_OFFLOAD=0
export __VK_LAYER_NV_optimus=non_NVIDIA_only
export DRI_PRIME=0
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json

exec "$@"
EOF
chmod 0755 "$HOME/.local/bin/loq-safe-env"

cat >"$HOME/.local/bin/code-battery" <<'EOF'
#!/usr/bin/env bash
exec "$HOME/.local/bin/loq-safe-env" /usr/bin/code \
  --disable-gpu \
  --disable-gpu-compositing \
  --disable-features=UseOzonePlatform,VaapiVideoDecoder,VaapiVideoEncoder,CanvasOopRasterization,RawDraw \
  "$@"
EOF
chmod 0755 "$HOME/.local/bin/code-battery"

cat >"$HOME/.local/bin/chrome-battery" <<'EOF'
#!/usr/bin/env bash
exec "$HOME/.local/bin/loq-safe-env" /usr/bin/google-chrome-stable \
  --disable-gpu \
  --disable-gpu-compositing \
  --disable-accelerated-video-decode \
  --disable-accelerated-video-encode \
  --disable-features=VaapiVideoDecoder,VaapiVideoEncoder,CanvasOopRasterization,RawDraw \
  "$@"
EOF
chmod 0755 "$HOME/.local/bin/chrome-battery"

if command -v zeditor >/dev/null 2>&1; then
  zed_cmd=zeditor
else
  zed_cmd=/usr/lib/zed/zed-editor
fi

cat >"$HOME/.local/bin/zed-battery" <<EOF
#!/usr/bin/env bash
exec "\$HOME/.local/bin/loq-safe-env" "$zed_cmd" "\$@"
EOF
chmod 0755 "$HOME/.local/bin/zed-battery"

cat >"$HOME/.local/share/applications/code-battery.desktop" <<'EOF'
[Desktop Entry]
Name=Visual Studio Code Battery
Comment=VS Code with GPU acceleration minimized for battery mode
Exec=/home/ciroautuori/.local/bin/code-battery %F
Icon=visual-studio-code
Type=Application
Categories=Development;IDE;
StartupNotify=true
MimeType=application/x-code-workspace;
Keywords=vscode;code;battery;
EOF

cat >"$HOME/.local/share/applications/chrome-battery.desktop" <<'EOF'
[Desktop Entry]
Name=Google Chrome Battery
Comment=Chrome with GPU acceleration disabled for battery mode
Exec=/home/ciroautuori/.local/bin/chrome-battery %U
Icon=google-chrome
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
Keywords=chrome;browser;battery;
EOF

cat >"$HOME/.local/share/applications/zed-battery.desktop" <<'EOF'
[Desktop Entry]
Name=Zed Battery
Comment=Zed with NVIDIA offload disabled for battery mode
Exec=/home/ciroautuori/.local/bin/zed-battery %U
Icon=zed
Type=Application
Categories=Utility;TextEditor;Development;IDE;
StartupNotify=true
MimeType=text/plain;application/x-zerosize;
Keywords=zed;battery;
EOF

update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

echo "Installed battery-safe launchers:"
echo "  code-battery"
echo "  chrome-battery"
echo "  zed-battery"
