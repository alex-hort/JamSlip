//
//  EditProfileRow.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 31/01/26.
//
import SwiftUI
// MARK: - Edit Profile Row

struct EditProfileRow: View {
    let label: String
    @Binding var value: String
    var placeholder: String = ""
    var isMultiline: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label)
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            
            if isMultiline {
                TextField(placeholder, text: $value, axis: .vertical)
                    .foregroundColor(Color(red: 0.4, green: 0.6, blue: 1.0))
                    .lineLimit(2)
                    .onChange(of: value) { _, newValue in
                        let lines = newValue.split(separator: "\n", omittingEmptySubsequences: false)
                        if lines.count > 2 {
                            value = lines.prefix(2).joined(separator: "\n")
                        }
                        
                        if value.count > 80 {
                            value = String(value.prefix(80))
                        }
                    }
            } else {
                TextField(placeholder, text: $value)
                    .foregroundColor(Color(red: 0.4, green: 0.6, blue: 1.0))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }
}
