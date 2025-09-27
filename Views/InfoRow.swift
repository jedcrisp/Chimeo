//
//  InfoRow.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}

#Preview {
    VStack(spacing: 0) {
        InfoRow(label: "Developer", value: "Jed Crisp")
        InfoRow(label: "Company", value: "OneTrack Consulting")
        InfoRow(label: "Contact", value: "jed@chimeo.app")
        InfoRow(label: "Website", value: "https://www.chimeo.app")
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
}
