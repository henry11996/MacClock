#!/bin/bash

# =============================================================================
# MacClock Notarization Script
# =============================================================================
# 使用方式:
#   ./scripts/notarize.sh
#
# 前置作業:
#   1. 設定環境變數 (或在下方直接填入):
#      export APPLE_ID="your@email.com"
#      export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"  # App-Specific Password
#      export TEAM_ID="XXXXXXXXXX"
#
#   2. 產生 App-Specific Password:
#      https://appleid.apple.com → 登入 → App-Specific Passwords → Generate
#
#   3. 確認 Xcode 已登入 Apple Developer 帳號
# =============================================================================

set -e  # 遇到錯誤立即停止

# 載入 .env 檔案
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | grep -v '^$' | xargs)
fi

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 專案設定
SCHEME="MacClock"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${SCHEME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
APP_PATH="${EXPORT_PATH}/${SCHEME}.app"
ZIP_PATH="${BUILD_DIR}/${SCHEME}.zip"
DMG_PATH="${BUILD_DIR}/${SCHEME}.dmg"

# =============================================================================
# 在此填入你的資訊 (或使用環境變數)
# =============================================================================
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-}"
TEAM_ID="${TEAM_ID:-}"
# =============================================================================

echo -e "${GREEN}=== MacClock Notarization Script ===${NC}"
echo ""

# 檢查必要資訊
if [ -z "$APPLE_ID" ] || [ -z "$APPLE_APP_PASSWORD" ] || [ -z "$TEAM_ID" ]; then
    echo -e "${RED}錯誤: 請設定以下環境變數:${NC}"
    echo "  export APPLE_ID=\"your@email.com\""
    echo "  export APPLE_APP_PASSWORD=\"xxxx-xxxx-xxxx-xxxx\""
    echo "  export TEAM_ID=\"XXXXXXXXXX\""
    echo ""
    echo "或直接編輯此腳本填入資訊"
    exit 1
fi

# 清理舊的建置
echo -e "${YELLOW}[1/7] 清理舊的建置...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 建立 ExportOptions.plist
echo -e "${YELLOW}[2/7] 建立 ExportOptions.plist...${NC}"
cat > "${BUILD_DIR}/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF

# Archive
echo -e "${YELLOW}[3/7] 建立 Archive...${NC}"
cd "$PROJECT_DIR"
xcodebuild -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    | grep -E "(Archive|error:|warning:|\*\*)" || true

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}Archive 失敗${NC}"
    exit 1
fi
echo -e "${GREEN}Archive 完成: $ARCHIVE_PATH${NC}"

# Export
echo -e "${YELLOW}[4/7] 匯出 App...${NC}"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" \
    | grep -E "(Export|error:|warning:|\*\*)" || true

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}匯出失敗${NC}"
    exit 1
fi
echo -e "${GREEN}匯出完成: $APP_PATH${NC}"

# 建立 ZIP
echo -e "${YELLOW}[5/7] 建立 ZIP...${NC}"
cd "$EXPORT_PATH"
ditto -c -k --keepParent "${SCHEME}.app" "$ZIP_PATH"
echo -e "${GREEN}ZIP 完成: $ZIP_PATH${NC}"

# 提交公證
echo -e "${YELLOW}[6/7] 提交公證 (這可能需要幾分鐘)...${NC}"
xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait

# Staple
echo -e "${YELLOW}[7/7] Staple 公證票證...${NC}"
xcrun stapler staple "$APP_PATH"

# 建立 DMG
echo -e "${YELLOW}[8/9] 建立 DMG 安裝檔...${NC}"

DMG_TEMP="${BUILD_DIR}/dmg_temp"
mkdir -p "$DMG_TEMP"
cp -R "$APP_PATH" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

hdiutil create -volname "$SCHEME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_TEMP"
echo -e "${GREEN}DMG 完成: $DMG_PATH${NC}"

# 公證 DMG
echo -e "${YELLOW}[9/9] 公證 DMG...${NC}"
xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait

xcrun stapler staple "$DMG_PATH"
echo -e "${GREEN}DMG 公證完成!${NC}"

# Git Tag & GitHub Release
echo ""
echo -e "${YELLOW}[10/11] 建立 Git Tag...${NC}"
read -p "請輸入版本號 (例如 0.0.2): " VERSION
VERSION="v${VERSION#v}"  # 確保有 v 前綴

git tag -a "$VERSION" -m "$(cat <<EOF
Release $VERSION

MacClock $VERSION
EOF
)"
echo -e "${GREEN}Tag $VERSION 建立完成${NC}"

echo -e "${YELLOW}[11/11] 推送並建立 GitHub Release...${NC}"
git push origin --tags

gh release create "$VERSION" "$DMG_PATH" \
  --title "MacClock $VERSION" \
  --notes "$(cat <<EOF
## MacClock $VERSION

### 下載
下載 \`MacClock.dmg\`，打開後將 App 拖曳至 Applications 資料夾即可。

### 系統需求
- macOS 26.0+
EOF
)"

echo ""
echo -e "${GREEN}=== 所有步驟完成! ===${NC}"
echo ""
echo "輸出檔案:"
echo "  App: $APP_PATH"
echo "  ZIP: $ZIP_PATH"
echo "  DMG: $DMG_PATH"
echo ""
echo -e "GitHub Release: ${GREEN}https://github.com/henry11996/MacClock/releases/tag/$VERSION${NC}"
echo ""
echo "開啟輸出資料夾..."
open "$BUILD_DIR"
