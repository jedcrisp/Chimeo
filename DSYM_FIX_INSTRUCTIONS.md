# Fixing dSYM Upload Issues for Firebase Frameworks

## Problem
When uploading to App Store Connect, you're getting errors about missing dSYM files for Firebase frameworks:
- FirebaseFirestoreInternal.framework
- absl.framework
- grpc.framework
- grpcpp.framework
- openssl_grpc.framework

## Solution

### Method 1: Automatic Fix (Recommended)

1. **Add Build Phase Script to Xcode:**
   - Open your project in Xcode
   - Select your target (Chimeo)
   - Go to "Build Phases" tab
   - Click "+" and select "New Run Script Phase"
   - Name it "Fix dSYM Generation"
   - Move it after "Copy Bundle Resources"
   - Add this script:
   ```bash
   "${SRCROOT}/scripts/fix_dsym.sh"
   ```

2. **Clean and Rebuild:**
   - Clean Build Folder (Cmd+Shift+K)
   - Archive your app (Product → Archive)
   - Upload to App Store Connect

### Method 2: Manual Fix (If Method 1 doesn't work)

1. **After Archiving:**
   - Run the fix script:
   ```bash
   ./fix_dsym_upload.sh
   ```

2. **Upload to App Store Connect:**
   - Use Xcode Organizer or Application Loader
   - The dSYM files should now be included

### Method 3: Podfile Configuration (Alternative)

If you have CocoaPods installed:

1. **Update Podfile:**
   ```ruby
   post_install do |installer|
     installer.pods_project.targets.each do |target|
       target.build_configurations.each do |config|
         config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf-with-dsym'
         config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
         config.build_settings['ENABLE_BITCODE'] = 'NO'
       end
     end
   end
   ```

2. **Run pod install:**
   ```bash
   pod install
   ```

## Verification

After applying the fix, you should see these dSYM files in your archive:
- `FirebaseFirestoreInternal.framework.dSYM`
- `absl.framework.dSYM`
- `grpc.framework.dSYM`
- `grpcpp.framework.dSYM`
- `openssl_grpc.framework.dSYM`

## Notes

- This issue is common with Firebase and gRPC frameworks when using CocoaPods
- The dSYM files are needed for crash symbolication in App Store Connect
- Make sure to test the upload process after applying the fix
