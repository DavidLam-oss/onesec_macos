#!/bin/zsh

# OnesecCore 精简打包签名脚本

set -e  # 遇到错误立即退出

# ============= 配置 =============
APP_NAME="OnesecCore"
BUNDLE_ID="com.ripplestar.oneseccore"
VERSION="1.0.0"
DEVELOPER_ID_CERT="Hangzhou RippleStar Technology Co., Ltd. (PNG2RBG62Z)"

# 路径
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
APP_BUNDLE="${BUILD_DIR}/release/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"

# ============= 颜色 =============
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_step() { echo "${BLUE}==>${NC} ${1}"; }
echo_ok() { echo "${GREEN}✓${NC} ${1}"; }

# ============= 创建 Entitlements =============
if [ ! -f "${PROJECT_ROOT}/entitlements.plist" ]; then
    cat > "${PROJECT_ROOT}/entitlements.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
EOF
fi

# ============= 清理 =============
echo_step "清理旧构建..."
rm -rf "${BUILD_DIR}/release"
mkdir -p "${BUILD_DIR}/release"

# ============= 构建 =============
echo_step "构建 ARM64 架构..."
swift build -c release --arch arm64 --build-path "${BUILD_DIR}"
echo_ok "ARM64 构建完成"

echo_step "构建 x86_64 架构..."
swift build -c release --arch x86_64 --build-path "${BUILD_DIR}"
echo_ok "x86_64 构建完成"

# 合并成 universal binary
echo_step "合并为 Universal Binary..."
ARM64_BINARY="${BUILD_DIR}/arm64-apple-macosx/release/${APP_NAME}"
X86_64_BINARY="${BUILD_DIR}/x86_64-apple-macosx/release/${APP_NAME}"
UNIVERSAL_BINARY="${BUILD_DIR}/universal/${APP_NAME}"

mkdir -p "${BUILD_DIR}/universal"
lipo -create "${ARM64_BINARY}" "${X86_64_BINARY}" -output "${UNIVERSAL_BINARY}"
echo_ok "Universal Binary 创建完成"

# 验证架构
echo_step "验证架构:"
lipo -info "${UNIVERSAL_BINARY}"

EXECUTABLE_PATH="${UNIVERSAL_BINARY}"

# ============= 创建 App Bundle =============
echo_step "创建 App Bundle..."
mkdir -p "${CONTENTS_DIR}/MacOS"
mkdir -p "${CONTENTS_DIR}/Resources"

# 复制可执行文件
cp "${EXECUTABLE_PATH}" "${CONTENTS_DIR}/MacOS/"
chmod +x "${CONTENTS_DIR}/MacOS/${APP_NAME}"

# 复制资源
[ -d "${PROJECT_ROOT}/Sources/Resources" ] && cp -R "${PROJECT_ROOT}/Sources/Resources/"* "${CONTENTS_DIR}/Resources/"
[ -f "${PROJECT_ROOT}/AppIcon.icns" ] && cp "${PROJECT_ROOT}/AppIcon.icns" "${CONTENTS_DIR}/Resources/"

# 创建 Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>OnesecCore 需要访问麦克风以录制音频</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>OnesecCore 需要访问辅助功能以监听键盘事件</string>
</dict>
</plist>
EOF
echo_ok "App Bundle 创建完成"

# ============= 签名 =============
echo_step "代码签名..."
codesign --force --sign "${DEVELOPER_ID_CERT}" \
    --options runtime \
    --timestamp \
    --deep \
    --entitlements "${PROJECT_ROOT}/entitlements.plist" \
    "${APP_BUNDLE}"
echo_ok "签名完成"

# ============= 验证 =============
echo_step "验证签名..."
codesign --verify --deep --strict "${APP_BUNDLE}"
echo_ok "签名验证通过"

# ============= 完成 =============
echo ""
echo "${GREEN}✓ 完成！${NC}"
echo "📦 ${APP_BUNDLE}"
du -sh "${APP_BUNDLE}"

