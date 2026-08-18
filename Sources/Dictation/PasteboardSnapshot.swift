import AppKit

/// A full copy of the pasteboard, so dictation can borrow it and hand it back.
///
/// Every item and every representation is captured, not just the string. A
/// naive `string(forType:)` save would silently destroy copied images, files
/// and rich text the moment someone dictated.
struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(reading pasteboard: NSPasteboard = .general) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            item.types.reduce(into: [:]) { partial, type in
                partial[type] = item.data(forType: type)
            }
        }
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        let restored = items.map { representations -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in representations {
                item.setData(data, forType: type)
            }
            return item
        }
        guard restored.isEmpty == false else { return }
        pasteboard.writeObjects(restored)
    }
}
