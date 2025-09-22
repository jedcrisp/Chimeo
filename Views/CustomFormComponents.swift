import SwiftUI

// MARK: - Custom Text Field
struct CustomTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    let isRequired: Bool
    let isMultiline: Bool
    let keyboardType: UIKeyboardType
    
    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        icon: String,
        isRequired: Bool = false,
        isMultiline: Bool = false,
        keyboardType: UIKeyboardType = .default
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isRequired = isRequired
        self.isMultiline = isMultiline
        self.keyboardType = keyboardType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                if isMultiline {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(3...6)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .autocapitalization(keyboardType == .emailAddress ? .none : .sentences)
                        .disableAutocorrection(keyboardType == .emailAddress)
                        .submitLabel(.next)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// MARK: - Custom Picker Field
struct CustomPickerField<T: CaseIterable & Hashable & RawRepresentable>: View where T.RawValue == String {
    let title: String
    @Binding var selection: T
    let icon: String
    let isRequired: Bool
    
    init(
        title: String,
        selection: Binding<T>,
        icon: String,
        isRequired: Bool = false
    ) {
        self.title = title
        self._selection = selection
        self.icon = icon
        self.isRequired = isRequired
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                
                Picker("", selection: $selection) {
                    ForEach(Array(T.allCases), id: \.self) { option in
                        Text(option.rawValue.capitalized)
                            .tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

