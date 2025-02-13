import SwiftUI

struct IconPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedIcon: String

    let icons = [
        "star.fill", "heart.fill", "bolt.fill", "leaf.fill", "globe",
        "text.bubble.fill", "pencil", "doc.fill", "book.fill", "bookmark.fill",
        "tag.fill", "checkmark.circle.fill", "bell.fill", "flag.fill", "paperclip",
        "link", "quote.bubble.fill", "list.bullet", "chart.bar.fill", "arrow.right.circle.fill",
        "arrow.triangle.2.circlepath", "magnifyingglass", "lightbulb.fill", "wand.and.stars",
        "brain.head.profile", "character.bubble", "globe.europe.africa.fill",
        "globe.americas.fill", "globe.asia.australia.fill", "character", "textformat",
        "folder.fill", "pencil.tip.crop.circle", "paintbrush", "text.justify", "scissors",
        "doc.on.clipboard", "arrow.up.doc", "arrow.down.doc", "doc.badge.plus",
        "bookmark.circle.fill", "bubble.left.and.bubble.right", "doc.text.magnifyingglass",
        "checkmark.rectangle", "trash", "quote.bubble", "abc", "globe.badge.chevron.backward",
        "character.book.closed", "book", "rectangle.and.text.magnifyingglass",
        "keyboard", "text.redaction", "a.magnify", "character.textbox",
        "character.cursor.ibeam", "cursorarrow.and.square.on.square.dashed", "rectangle.and.pencil.and.ellipsis",
        "bubble.middle.bottom", "bubble.left", "text.badge.star", "text.insert", "arrow.uturn.backward.circle.fill"
    ]

    let columns = Array(repeating: GridItem(.flexible()), count: 8)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Icon")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(icons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            dismiss()
                        }) {
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 32, height: 32)
                                .foregroundColor(selectedIcon == icon ? .white : .primary)
                                .background(selectedIcon == icon ? Color.accentColor : Color.clear)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 300)
        .background(Color(.windowBackgroundColor))
    }
}
