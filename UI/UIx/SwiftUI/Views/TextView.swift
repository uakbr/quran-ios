//
//  TextView.swift
//  
//
//  Migrated from UIViewRepresentable to native SwiftUI.TextEditor for better performance
//

import SwiftUI

/// A SwiftUI text editor that provides multiline text editing capabilities
public struct TextView: View {
    // MARK: Lifecycle

    public init(_ text: Binding<String>, editing: Binding<Bool>) {
        _text = text
        _editing = editing
    }

    // MARK: Public

    public var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .background(Color.clear)
            .onTapGesture {
                if !editing {
                    editing = true
                }
            }
            .onChange(of: editing) { _, isEditing in
                // Handle editing state changes
                if !isEditing {
                    // End editing
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
    }

    // MARK: Private

    @Binding private var text: String
    @Binding private var editing: Bool
}

// MARK: - Modifiers

extension TextView {
    /// Set the font using SwiftUI's text style
    public func font(_ textStyle: Font.TextStyle) -> Self {
        font(.system(textStyle))
    }

    /// Set a custom font
    public func font(_ font: Font) -> Self {
        var view = self
        view.font = font
        return view
    }
}

// swiftlint:disable line_length
struct TextView_Previews: PreviewProvider {
    @State static var editing: Bool = true

    static var previews: some View {
        VStack {
            TextView(
                .constant("Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."),
                editing: $editing
            )
            .font(UIFont.TextStyle.body)
            .border(Color.red, width: 1)
            .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}

// swiftlint:enable line_length
