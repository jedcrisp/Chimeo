#!/bin/bash

# Xcode Build Phase Script to fix dSYM issues
# Add this as a "Run Script Phase" after "Copy Bundle Resources"

echo "🔧 Fixing dSYM generation for Firebase frameworks..."

# Get the build directory
BUILD_DIR="${BUILT_PRODUCTS_DIR}"
DSYM_DIR="${DWARF_DSYM_FOLDER_PATH}"

# Ensure dSYM directory exists
mkdir -p "${DSYM_DIR}"

# Function to create dSYM for framework
create_framework_dsym() {
    local framework_name=$1
    local framework_path="${BUILD_DIR}/${PRODUCT_NAME}.app/Frameworks/${framework_name}.framework"
    
    if [ -d "${framework_path}" ]; then
        echo "📦 Creating dSYM for ${framework_name}..."
        
        # Create dSYM bundle
        local dsym_bundle="${DSYM_DIR}/${framework_name}.framework.dSYM"
        mkdir -p "${dsym_bundle}/Contents/Resources/DWARF"
        
        # Copy the binary
        if [ -f "${framework_path}/${framework_name}" ]; then
            cp "${framework_path}/${framework_name}" "${dsym_bundle}/Contents/Resources/DWARF/"
            
            # Create Info.plist
            cat > "${dsym_bundle}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.apple.xcode.dsym.${framework_name}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${framework_name}</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
EOF
            echo "✅ Created dSYM for ${framework_name}"
        else
            echo "⚠️  Binary not found for ${framework_name}"
        fi
    else
        echo "⚠️  Framework not found: ${framework_name}"
    fi
}

# Create dSYMs for Firebase frameworks
create_framework_dsym "FirebaseFirestoreInternal"
create_framework_dsym "absl"
create_framework_dsym "grpc"
create_framework_dsym "grpcpp"
create_framework_dsym "openssl_grpc"

echo "🎉 dSYM generation complete!"
