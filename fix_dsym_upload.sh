#!/bin/bash

# Script to fix dSYM upload issues for Firebase frameworks
# This script should be run after archiving your app

echo "🔧 Fixing dSYM upload issues..."

# Find the archive path
ARCHIVE_PATH=$(find ~/Library/Developer/Xcode/Archives -name "*.xcarchive" -type d | head -1)

if [ -z "$ARCHIVE_PATH" ]; then
    echo "❌ No archive found. Please archive your app first."
    exit 1
fi

echo "📁 Found archive: $ARCHIVE_PATH"

# Create dSYMs directory if it doesn't exist
DSYM_DIR="$ARCHIVE_PATH/dSYMs"
mkdir -p "$DSYM_DIR"

# Function to create dSYM for a framework
create_dsym() {
    local framework_name=$1
    local framework_path="$ARCHIVE_PATH/Products/Applications/Chimeo.app/Frameworks/$framework_name.framework"
    
    if [ -d "$framework_path" ]; then
        echo "📦 Creating dSYM for $framework_name..."
        
        # Create dSYM bundle
        local dsym_bundle="$DSYM_DIR/$framework_name.framework.dSYM"
        mkdir -p "$dsym_bundle/Contents/Resources/DWARF"
        
        # Copy the binary and create dSYM
        cp "$framework_path/$framework_name" "$dsym_bundle/Contents/Resources/DWARF/"
        
        # Create Info.plist for dSYM
        cat > "$dsym_bundle/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.apple.xcode.dsym.$framework_name</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$framework_name</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
EOF
        
        echo "✅ Created dSYM for $framework_name"
    else
        echo "⚠️  Framework not found: $framework_name"
    fi
}

# Create dSYMs for Firebase frameworks
create_dsym "FirebaseFirestoreInternal"
create_dsym "absl"
create_dsym "grpc"
create_dsym "grpcpp"
create_dsym "openssl_grpc"

echo "🎉 dSYM fix complete!"
echo "📤 You can now upload to App Store Connect"
