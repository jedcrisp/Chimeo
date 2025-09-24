//
//  FilterChip.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HStack(spacing: 8) {
        FilterChip(
            title: "All",
            isSelected: true,
            action: {}
        )
        
        FilterChip(
            title: "Business",
            isSelected: false,
            action: {}
        )
        
        FilterChip(
            title: "Government",
            isSelected: false,
            action: {}
        )
        
        FilterChip(
            title: "Non-profit",
            isSelected: false,
            action: {}
        )
    }
    .padding()
}
