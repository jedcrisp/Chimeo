import Foundation
import FirebaseStorage
import UIKit

// MARK: - File Upload Service
class FileUploadService: ObservableObject {
    
    private let storage = Storage.storage()
    
    init() {
        // Ensure we're using the correct bucket
        print("🏗️ FileUploadService initialized")
        print("   📦 Default bucket: \(storage.app.options.storageBucket ?? "nil")")
    }
    
    // MARK: - Photo Upload Methods
    func uploadUserProfilePhoto(_ image: UIImage, userId: String) async throws -> String {
        print("📸 Uploading user profile photo for user: \(userId)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FileUploadError.invalidImageData
        }
        
        let fileName = "profile_\(userId)_\(Date().timeIntervalSince1970).jpg"
        let filePath = "users/\(userId)/profile/\(fileName)"
        
        return try await uploadImage(imageData, to: filePath)
    }
    
    func uploadOrganizationLogo(_ image: UIImage, organizationId: String, organizationName: String? = nil) async throws -> String {
        print("🏢 Uploading organization logo for: \(organizationId)")
        print("   📏 Image size: \(image.size)")
        print("   🎨 Image scale: \(image.scale)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert image to JPEG data")
            throw FileUploadError.invalidImageData
        }
        
        print("   📊 JPEG data size: \(imageData.count) bytes")
        
        let fileName = "logo_\(Date().timeIntervalSince1970).jpg"
        
        // Use proper organization folder structure
        let sanitizedOrgName = organizationName?.replacingOccurrences(of: " ", with: "_").lowercased() ?? organizationId
        let filePath = "organizations/\(sanitizedOrgName)/photos/\(fileName)"
        
        print("   📁 File path: \(filePath)")
        print("   📄 File name: \(fileName)")
        print("   🏢 Organization ID: \(organizationId)")
        print("   🏢 Sanitized org name: \(sanitizedOrgName)")
        
        // Using simple path structure, no need to create folders
        
        let result = try await uploadImage(imageData, to: filePath)
        print("✅ uploadOrganizationLogo completed, returning: \(result)")
        return result
    }
    
    // MARK: - Ensure Folder Structure Exists
    private func ensureOrganizationLogosFolderExists(organizationId: String) async throws {
        print("📁 Ensuring organization logos folder structure exists for: \(organizationId)")
        
        // Create a placeholder file to establish the folder structure
        let placeholderPath = "organizations/\(organizationId)/logos/.placeholder"
        let placeholderData = "".data(using: .utf8) ?? Data()
        
        do {
            let storageRef = storage.reference().child(placeholderPath)
            let metadata = StorageMetadata()
            metadata.contentType = "text/plain"
            
            // Upload a tiny placeholder file to create the folder structure
            _ = try await storageRef.putData(placeholderData, metadata: metadata)
            print("✅ Organization logos folder structure created")
            
            // Clean up the placeholder file
            try await storageRef.delete()
            print("✅ Placeholder file cleaned up")
            
        } catch {
            print("⚠️ Could not create folder structure (this might be normal if it already exists): \(error)")
            // Don't throw here - the folder might already exist
        }
    }
    
    func uploadAlertPhoto(_ image: UIImage, alertId: String, organizationId: String) async throws -> String {
        print("🚨 Uploading alert photo for alert: \(alertId)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FileUploadError.invalidImageData
        }
        
        let fileName = "alert_\(alertId)_\(Date().timeIntervalSince1970).jpg"
        let filePath = "organizations/\(organizationId)/alerts/\(alertId)/photos/\(fileName)"
        
        return try await uploadImage(imageData, to: filePath)
    }
    
    func uploadIncidentPhoto(_ image: UIImage, incidentId: String, userId: String) async throws -> String {
        print("📸 Uploading incident photo for incident: \(incidentId)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FileUploadError.invalidImageData
        }
        
        let fileName = "incident_\(incidentId)_\(Date().timeIntervalSince1970).jpg"
        let filePath = "incidents/\(incidentId)/photos/\(fileName)"
        
        return try await uploadImage(imageData, to: filePath)
    }
    
    // MARK: - Generic Photo Upload
    func uploadGenericPhoto(_ image: UIImage, source: String, identifier: String) async throws -> String {
        print("📸 Uploading generic photo for \(source): \(identifier)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FileUploadError.invalidImageData
        }
        
        let fileName = "\(source)_\(identifier)_\(Date().timeIntervalSince1970).jpg"
        let filePath = "uploads/\(source)/\(fileName)"
        
        return try await uploadImage(imageData, to: filePath)
    }
    
    // MARK: - Core Upload Logic
    private func uploadImage(_ imageData: Data, to filePath: String) async throws -> String {
        print("🔄 Starting image upload to: \(filePath)")
        
        let storageRef = storage.reference().child(filePath)
        print("   📍 Storage reference created")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        print("   📋 Metadata created: \(metadata.contentType ?? "nil")")
        
        print("   ⬆️ Starting upload...")
        let uploadTask = storageRef.putData(imageData, metadata: metadata)
        
        // Wait for upload to complete
        print("   ⏳ Waiting for upload to complete...")
        _ = try await uploadTask
        print("   ✅ Upload completed successfully")
        
        // Add a small delay to ensure the file is fully processed
        print("   ⏳ Waiting for file to be fully processed...")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // Get download URL using Firebase SDK
        print("   🔗 Getting download URL...")
        print("   📍 Storage reference path: \(storageRef.fullPath)")
        print("   📍 Storage reference bucket: \(storageRef.bucket)")
        
        do {
            let downloadURL = try await storageRef.downloadURL()
            print("✅ Image uploaded successfully")
            print("   📍 Path: \(filePath)")
            print("   🔗 URL: \(downloadURL.absoluteString)")
            return downloadURL.absoluteString
        } catch {
            print("❌ First attempt failed, trying alternative method...")
            
            // Try using the bucket-specific reference
            let bucketRef = storage.reference(forURL: "gs://\(storage.app.options.storageBucket ?? "chimeo-96dfc.firebasestorage.app")/\(filePath)")
            do {
                let downloadURL = try await bucketRef.downloadURL()
                print("✅ Image uploaded successfully (alternative method)")
                print("   📍 Path: \(filePath)")
                print("   🔗 URL: \(downloadURL.absoluteString)")
                return downloadURL.absoluteString
            } catch {
                print("❌ Alternative method also failed: \(error)")
            }
            print("❌ Failed to get download URL: \(error)")
            print("   📍 Attempted path: \(filePath)")
            print("   📍 Storage ref path: \(storageRef.fullPath)")
            
            // Try to check if the file exists by getting metadata
            do {
                let metadata = try await storageRef.getMetadata()
                print("   📋 File metadata exists: \(metadata.name)")
                print("   📋 File size: \(metadata.size)")
                print("   📋 File content type: \(metadata.contentType ?? "nil")")
            } catch {
                print("   ❌ File metadata not accessible: \(error)")
            }
            
            throw error
        }
    }
    
    // MARK: - File Deletion
    func deleteFile(at path: String) async throws {
        print("🗑️ Deleting file at path: \(path)")
        
        let storageRef = storage.reference().child(path)
        try await storageRef.delete()
        
        print("✅ File deleted successfully")
    }
    
    // MARK: - List Files in Storage Path
    func listFilesInPath(_ path: String) async throws -> [String] {
        let storageRef = storage.reference().child(path)
        var files: [String] = []
        
        do {
            let listResult = try await storageRef.listAll()
            
            for item in listResult.items {
                files.append(item.name)
            }
            
        } catch {
            throw error
        }
        
        return files
    }
    
    // MARK: - Get Organization Logo URL
    func getOrganizationLogoURL(organizationId: String) async throws -> String? {
        let photosPath = "organizations/\(organizationId)/photos"
        
        do {
            let files = try await listFilesInPath(photosPath)
            
            // Look for logo files (files that start with "logo_")
            let logoFiles = files.filter { $0.hasPrefix("logo_") }
            
            if let logoFile = logoFiles.first {
                let logoPath = "\(photosPath)/\(logoFile)"
                let storageRef = storage.reference().child(logoPath)
                let downloadURL = try await storageRef.downloadURL()
                return downloadURL.absoluteString
            } else {
                return nil
            }
            
        } catch {
            return nil
        }
    }
    
    // MARK: - File Download
    func downloadImage(from url: String) async throws -> UIImage {
        print("⬇️ Downloading image from: \(url)")
        
        guard let imageURL = URL(string: url) else {
            throw FileUploadError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        
        guard let image = UIImage(data: data) else {
            throw FileUploadError.invalidImageData
        }
        
        print("✅ Image downloaded successfully")
        return image
    }
    
    // MARK: - Utility Methods
    func getFileSize(for url: String) async throws -> Int64 {
        print("📏 Getting file size for: \(url)")
        
        guard let imageURL = URL(string: url) else {
            throw FileUploadError.invalidURL
        }
        
        let (_, response) = try await URLSession.shared.data(from: imageURL)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FileUploadError.invalidResponse
        }
        
        let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "0"
        let size = Int64(contentLength) ?? 0
        
        print("✅ File size: \(size) bytes")
        return size
    }
    
    func validateImage(_ image: UIImage) -> Bool {
        // Check if image is not empty
        guard image.size.width > 0 && image.size.height > 0 else {
            return false
        }
        
        // Check if image dimensions are reasonable (not too small, not too large)
        let minDimension: CGFloat = 100
        let maxDimension: CGFloat = 4000
        
        guard image.size.width >= minDimension && image.size.height >= minDimension else {
            return false
        }
        
        guard image.size.width <= maxDimension && image.size.height <= maxDimension else {
            return false
        }
        
        return true
    }
}

// MARK: - File Upload Errors
enum FileUploadError: Error, LocalizedError {
    case invalidImageData
    case invalidURL
    case invalidResponse
    case uploadFailed
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .uploadFailed:
            return "Failed to upload file"
        case .downloadFailed:
            return "Failed to download file"
        }
    }
}
