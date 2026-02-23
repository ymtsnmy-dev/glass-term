import AppKit
import Combine
import Foundation

struct CopiedBlock: Identifiable, Equatable {
    let id: UUID
    let formattedText: String
    let copiedAt: Date
}

@MainActor
final class CopyQueueManager: ObservableObject {
    @Published private(set) var items: [CopiedBlock] = []

    func append(block: Block) {
        let copiedBlock = CopiedBlock(
            id: UUID(),
            formattedText: Self.formattedText(for: block),
            copiedAt: Date()
        )
        items.append(copiedBlock)
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func clear() {
        items.removeAll(keepingCapacity: true)
    }

    func copyAllToPasteboard() {
        let combined = items
            .map(\.formattedText)
            .joined(separator: "\n\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(combined, forType: .string)
    }

    private static func formattedText(for block: Block) -> String {
        let command = block.command.strippingANSIEscapeSequences()
        let stdout = block.stdout.strippingANSIEscapeSequences()
        let stderr = block.stderr.strippingANSIEscapeSequences()

        var result = "$ \(command)\n----------------------------------------\n"
        result += stdout

        if !stderr.isEmpty {
            if !stdout.isEmpty && !result.hasSuffix("\n") {
                result += "\n"
            }
            result += stderr
        }

        return result
    }
}

private extension String {
    func strippingANSIEscapeSequences() -> String {
        let scalars = Array(unicodeScalars)
        var output = String.UnicodeScalarView()
        var index = 0

        while index < scalars.count {
            let scalar = scalars[index]

            switch scalar.value {
            case 0x1B:
                index = Self.skipEscapeSequence(in: scalars, from: index)
            case 0x9B:
                index = Self.skipCSI(in: scalars, from: index + 1)
            case 0x9D:
                index = Self.skipOSC(in: scalars, from: index + 1)
            case 0x90, 0x98, 0x9E, 0x9F:
                index = Self.skipStringSequence(in: scalars, from: index + 1)
            default:
                output.append(scalar)
                index += 1
            }
        }

        return String(output)
    }

    static func skipEscapeSequence(in scalars: [UnicodeScalar], from escapeIndex: Int) -> Int {
        let nextIndex = escapeIndex + 1
        guard nextIndex < scalars.count else {
            return scalars.count
        }

        switch scalars[nextIndex].value {
        case 0x5B:
            return skipCSI(in: scalars, from: nextIndex + 1)
        case 0x5D:
            return skipOSC(in: scalars, from: nextIndex + 1)
        case 0x50, 0x58, 0x5E, 0x5F:
            return skipStringSequence(in: scalars, from: nextIndex + 1)
        default:
            var index = nextIndex
            while index < scalars.count {
                let value = scalars[index].value
                if (0x20...0x2F).contains(value) {
                    index += 1
                    continue
                }
                return index + 1
            }
            return scalars.count
        }
    }

    static func skipCSI(in scalars: [UnicodeScalar], from startIndex: Int) -> Int {
        var index = startIndex
        while index < scalars.count {
            let value = scalars[index].value
            if (0x40...0x7E).contains(value) {
                return index + 1
            }
            index += 1
        }
        return scalars.count
    }

    static func skipOSC(in scalars: [UnicodeScalar], from startIndex: Int) -> Int {
        var index = startIndex
        while index < scalars.count {
            let value = scalars[index].value
            if value == 0x07 || value == 0x9C {
                return index + 1
            }
            if value == 0x1B,
               index + 1 < scalars.count,
               scalars[index + 1].value == 0x5C {
                return index + 2
            }
            index += 1
        }
        return scalars.count
    }

    static func skipStringSequence(in scalars: [UnicodeScalar], from startIndex: Int) -> Int {
        var index = startIndex
        while index < scalars.count {
            let value = scalars[index].value
            if value == 0x9C {
                return index + 1
            }
            if value == 0x1B,
               index + 1 < scalars.count,
               scalars[index + 1].value == 0x5C {
                return index + 2
            }
            index += 1
        }
        return scalars.count
    }
}
