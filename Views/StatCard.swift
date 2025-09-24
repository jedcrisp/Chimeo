//
//  StatCard.swift
//  Chimeo
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            // Value
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Title
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

#Preview {
    HStack(spacing: 16) {
        StatCard(
            title: "Pending",
            value: "12",
            icon: "clock.fill",
            color: .orange
        )
        
        StatCard(
            title: "Under Review",
            value: "5",
            icon: "magnifyingglass",
            color: .blue
        )
        
        StatCard(
            title: "Total",
            value: "47",
            icon: "doc.text.fill",
            color: .gray
        )
    }
    .padding()
}
