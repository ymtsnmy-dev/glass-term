import SwiftUI

struct TabBarView: View {
    struct Item: Identifiable, Equatable {
        let id: UUID
        let title: String
        let isActive: Bool
        let isTerminated: Bool
    }

    let items: [Item]
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(items) { item in
                        tabChip(item)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
            )
            .padding(.trailing, 10)
        }
        .background(Color.black.opacity(0.96))
    }

    @ViewBuilder
    private func tabChip(_ item: Item) -> some View {
        HStack(spacing: 8) {
            Button {
                onSelect(item.id)
            } label: {
                HStack(spacing: 6) {
                    if item.isTerminated {
                        Circle()
                            .fill(Color.red.opacity(0.9))
                            .frame(width: 6, height: 6)
                    }
                    Text(item.title)
                        .lineLimit(1)
                        .font(.system(size: 12, weight: item.isActive ? .semibold : .regular))
                        .foregroundStyle(item.isActive ? Color.white : Color.white.opacity(0.8))
                }
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                onClose(item.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(item.isActive ? Color.white.opacity(0.18) : Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(item.isActive ? Color.white.opacity(0.25) : Color.clear, lineWidth: 1)
        )
    }
}
