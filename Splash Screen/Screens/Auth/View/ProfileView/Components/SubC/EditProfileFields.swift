//
//  EditProfileFields.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 31/01/26.
//
import SwiftUI

struct EditProfileFields: View {
    
    @Binding var fullName: String
    @Binding var bio: String
    
    var body: some View {
        VStack(spacing: 0) {
            
            // NAME ROW
            fieldRow(
                title: "Name",
                value: $fullName
            )
            
            divider
            
            // BIO ROW
            bioRow
            
        }
        .background(Color.black)
    }
    
    // MARK: - Components
    
    private func fieldRow(title: String, value: Binding<String>) -> some View {
        HStack(spacing: 8) { // 🔥 menos spacing
            
            Text(title)
                .foregroundColor(.gray)
                .font(.system(size: 16))
                .frame(width: 50, alignment: .leading)

            
            TextField("", text: value)
                .foregroundColor(.blue)
                .font(.system(size: 17))
        }
        .padding(.horizontal)
        .padding(.vertical, 18)
    }




    
    private var bioRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text("Bio")
                .foregroundColor(.white)
                .font(.system(size: 17, weight: .semibold))
            
            TextEditor(text: $bio)
                .frame(minHeight: 80)
                .foregroundColor(.blue)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .padding(.horizontal)
        .padding(.vertical, 18)
    }
    
    private var divider: some View {
        Divider()
            .background(Color.white.opacity(0.1))
    }
}

