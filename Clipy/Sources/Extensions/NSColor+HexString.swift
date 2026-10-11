//
//  NSColor+HexString.swift
//
//  Clipy
//

import Cocoa

extension NSColor {
    /// Parses `RGB`, `RGBA`, `RRGGBB` or `RRGGBBAA`, with or without a leading `#`.
    /// Whether this succeeds decides which clips are stored as colour codes.
    convenience init?(hexString: String) {
        let hex = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        // Int64(_:radix:) also accepts a leading "+" or "-"; kept so detection matches earlier releases.
        guard let value = Int64(hex, radix: 16) else { return nil }
        func channel(_ shift: Int64, bits: Int64) -> CGFloat {
            let raw = (value >> shift) & (bits == 4 ? 0xF : 0xFF)
            return CGFloat(bits == 4 ? (raw << 4) + raw : raw) / 255
        }
        switch hex.count {
        case 3:
            self.init(red: channel(8, bits: 4), green: channel(4, bits: 4), blue: channel(0, bits: 4), alpha: 1)
        case 4:
            self.init(red: channel(12, bits: 4), green: channel(8, bits: 4), blue: channel(4, bits: 4), alpha: channel(0, bits: 4))
        case 6:
            self.init(red: channel(16, bits: 8), green: channel(8, bits: 8), blue: channel(0, bits: 8), alpha: 1)
        case 8:
            self.init(red: channel(24, bits: 8), green: channel(16, bits: 8), blue: channel(8, bits: 8), alpha: channel(0, bits: 8))
        default:
            return nil
        }
    }
}
