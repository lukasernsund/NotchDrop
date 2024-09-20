import SwiftUI

struct ExpandingSearchBar: View {
    @Binding var searchText: String
    @Binding var isExpanded: Bool
    @FocusState private var isFocused: Bool
    @State private var isHovered: Bool = false

    private let iconSize: CGFloat = 20
    private let expandedWidth: CGFloat = 320
    private let height: CGFloat = 36

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isExpanded || isHovered ? .primary : .secondary)
                .frame(width: iconSize, height: iconSize)
                .scaleEffect(isHovered && !isExpanded ? 1.4 : !isExpanded ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
                .padding(.horizontal, (height - iconSize))
                .contentShape(Rectangle())
                .onTapGesture {
                    if isExpanded {
                        collapseSearchBar()
                    } else {
                        expandSearchBar()
                    }
                }

            if isExpanded {
                TextField("Search", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isFocused)
                    .frame(height: height)
                    .padding(.horizontal, 8)
                    .onSubmit {
                        if searchText.isEmpty {
                            collapseSearchBar()
                        }
                    }

                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 8)
                }
            }
        }
        .frame(width: isExpanded ? expandedWidth : height, height: height)
        .background(Color.clear)
        .cornerRadius(height / 2)
        .overlay(
            RoundedRectangle(cornerRadius: height / 2)
                .stroke(isExpanded ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
    }

    private func expandSearchBar() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isExpanded = true
            isFocused = true
        }
    }

    private func collapseSearchBar() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isExpanded = false
            isFocused = false
            searchText = ""
        }
    }
}
