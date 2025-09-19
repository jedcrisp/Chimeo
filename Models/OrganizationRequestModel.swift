import Foundation
import CoreLocation
import SwiftUI





// MARK: - Verification Document
struct VerificationDocument: Codable, Identifiable {
    let id: String
    let name: String
    let type: DocumentType
    let url: String
    let uploadedAt: Date
    let verified: Bool
    let verifiedAt: Date?
    let verifiedBy: String?
    
    init(name: String, type: DocumentType, url: String) {
        self.id = UUID().uuidString
        self.name = name
        self.type = type
        self.url = url
        self.uploadedAt = Date()
        self.verified = false
        self.verifiedAt = nil
        self.verifiedBy = nil
    }
}

// MARK: - Document Types
enum DocumentType: String, CaseIterable, Codable {
    case businessLicense = "business_license"
    case taxExempt = "tax_exempt"
    case incorporation = "incorporation"
    case governmentId = "government_id"
    case utilityBill = "utility_bill"
    case leaseAgreement = "lease_agreement"
    case insurance = "insurance"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .businessLicense: return "Business License"
        case .taxExempt: return "Tax Exempt Certificate"
        case .incorporation: return "Articles of Incorporation"
        case .governmentId: return "Government ID"
        case .utilityBill: return "Utility Bill"
        case .leaseAgreement: return "Lease Agreement"
        case .insurance: return "Insurance Certificate"
        case .other: return "Other Document"
        }
    }
    
    var required: Bool {
        switch self {
        case .businessLicense, .taxExempt, .incorporation:
            return true
        default:
            return false
        }
    }
}

 