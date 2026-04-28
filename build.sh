#!/usr/bin/env bash
# build.sh — 编译 CCSwitch，组装 .app Bundle，签名，打带拖拽安装界面的 DMG
set -euo pipefail

PRODUCT_NAME="CCSwitch"
VERSION="1.0.0"
VOL_NAME="$PRODUCT_NAME $VERSION"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
STAGING_DIR="$PROJECT_DIR/dist"
APP_DIR="$STAGING_DIR/$PRODUCT_NAME.app"
DMG_PATH="$STAGING_DIR/$PRODUCT_NAME-$VERSION.dmg"
TMP_DMG="$STAGING_DIR/tmp_rw.dmg"

# ── 1. 编译 ──────────────────────────────────────────────
echo "▶ Building release binary..."
swift build -c release 2>&1 | grep -v "^warning:"

BINARY="$BUILD_DIR/$PRODUCT_NAME"
[ -f "$BINARY" ] || { echo "✘ Binary not found: $BINARY"; exit 1; }

# ── 2. 组装 .app Bundle ───────────────────────────────────
echo "▶ Assembling .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BINARY"                               "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"
cp "$PROJECT_DIR/CCSwitch/Info.plist"      "$APP_DIR/Contents/Info.plist"
printf 'APPL????' >                        "$APP_DIR/Contents/PkgInfo"
if [ -f "$PROJECT_DIR/CCSwitch/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/CCSwitch/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "  ✔ Icon embedded"
fi

# ── 3. 代码签名 ───────────────────────────────────────────
echo "▶ Code signing..."
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep "Developer ID Application" | head -1 \
    | grep -o '"[^"]*"' | tr -d '"' || true)
if [ -n "$IDENTITY" ]; then
    echo "  Using: $IDENTITY"
    codesign --force --deep --sign "$IDENTITY" \
        --entitlements "$PROJECT_DIR/CCSwitch/CCSwitch.entitlements" \
        --options runtime "$APP_DIR"
else
    echo "  No Developer ID — using ad-hoc signature"
    codesign --force --deep --sign - "$APP_DIR"
fi
codesign --verify --verbose=1 "$APP_DIR" 2>&1 | grep -E "valid|satisfies|error" || true

# ── 4. 打 DMG（拖拽安装界面）────────────────────────────
echo "▶ Creating drag-to-install DMG..."
rm -f "$DMG_PATH" "$TMP_DMG"

# 4a. 创建可写临时 DMG
hdiutil create -size 20m -fs HFS+ -volname "$VOL_NAME" -ov "$TMP_DMG" -quiet

# 4b. 挂载，获取挂载点
MOUNT_DIR=$(hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen \
    | awk '/Apple_HFS/ {for(i=3;i<=NF;i++) printf $i (i<NF?" ":"\n")}')
echo "  Mounted: $MOUNT_DIR"

# 4c. 布置内容
cp -R "$APP_DIR" "$MOUNT_DIR/"
ln -sf /Applications "$MOUNT_DIR/Applications"
if [ -f "$PROJECT_DIR/CCSwitch/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/CCSwitch/AppIcon.icns" "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
fi

# 4d. AppleScript 设置 Finder 窗口布局
osascript - "$MOUNT_DIR" "$PRODUCT_NAME" "$VOL_NAME" <<'APPLESCRIPT'
on run {mountPath, appName, volName}
    tell application "Finder"
        -- 用路径方式引用磁盘，避免按名查找歧义
        set dmgDisk to disk volName
        open dmgDisk

        -- 等待 Finder 完成打开
        delay 1

        tell container window of dmgDisk
            set current view to icon view
            set toolbar visible to false
            set statusbar visible to false
            set the bounds to {200, 120, 740, 440}
        end tell

        -- 等待 icon view 生效
        delay 1

        tell icon view options of container window of dmgDisk
            set arrangement to not arranged
            set icon size to 120
        end tell

        -- 设置图标位置
        set position of item (appName & ".app") of dmgDisk to {140, 160}
        set position of item "Applications" of dmgDisk to {400, 160}

        update dmgDisk without registering applications
        delay 2
        close container window of dmgDisk
    end tell
end run
APPLESCRIPT

# 4e. 卸载并压缩成只读 DMG
sync
hdiutil detach "$MOUNT_DIR" -quiet
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 \
    -o "$DMG_PATH" -quiet
rm -f "$TMP_DMG"

echo ""
echo "✔ Done!"
echo "  DMG : $DMG_PATH  ($(du -sh "$DMG_PATH" | cut -f1))"
echo "  App : $APP_DIR   ($(du -sh "$APP_DIR"  | cut -f1))"
