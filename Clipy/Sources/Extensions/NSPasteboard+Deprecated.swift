//
//  NSPasteboard+Modern.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Modernized pasteboard type aliases.
//  Uses proper UTI-based types instead of legacy Carbon strings.
//

import Cocoa

extension NSPasteboard.PasteboardType {

    // Modern UTI-based pasteboard types
    // These replace the old "NSStringPboardType" etc.

    static let clipyString: NSPasteboard.PasteboardType = .string
    static let clipyRTF: NSPasteboard.PasteboardType = .rtf
    static let clipyRTFD: NSPasteboard.PasteboardType = .init("com.apple.flat-rtfd")
    static let clipyPDF: NSPasteboard.PasteboardType = .pdf
    static let clipyFilenames: NSPasteboard.PasteboardType = .fileURL
    static let clipyURL: NSPasteboard.PasteboardType = .URL
    static let clipyTIFF: NSPasteboard.PasteboardType = .tiff

    // Legacy aliases for reading old data
    // macOS still recognizes these when reading from pasteboard
    static let legacyString = NSPasteboard.PasteboardType(rawValue: "NSStringPboardType")
    static let legacyRTF = NSPasteboard.PasteboardType(rawValue: "NSRTFPboardType")
    static let legacyRTFD = NSPasteboard.PasteboardType(rawValue: "NSRTFDPboardType")
    static let legacyPDF = NSPasteboard.PasteboardType(rawValue: "NSPDFPboardType")
    static let legacyFilenames = NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
    static let legacyURL = NSPasteboard.PasteboardType(rawValue: "NSURLPboardType")
    static let legacyTIFF = NSPasteboard.PasteboardType(rawValue: "NSTIFFPboardType")

    /// Check if this type matches a known type (either modern or legacy)
    func isStringType() -> Bool {
        return self == .clipyString || self == .legacyString
    }
    func isRTFType() -> Bool {
        return self == .clipyRTF || self == .legacyRTF
    }
    func isRTFDType() -> Bool {
        return self == .clipyRTFD || self == .legacyRTFD
    }
    func isPDFType() -> Bool {
        return self == .clipyPDF || self == .legacyPDF
    }
    func isFilenamesType() -> Bool {
        return self == .clipyFilenames || self == .legacyFilenames
    }
    func isURLType() -> Bool {
        return self == .clipyURL || self == .legacyURL
    }
    func isTIFFType() -> Bool {
        return self == .clipyTIFF || self == .legacyTIFF
    }

    /// Normalize a pasteboard type to its modern equivalent
    var normalized: NSPasteboard.PasteboardType {
        if isStringType() { return .clipyString }
        if isRTFType() { return .clipyRTF }
        if isRTFDType() { return .clipyRTFD }
        if isPDFType() { return .clipyPDF }
        if isFilenamesType() { return .clipyFilenames }
        if isURLType() { return .clipyURL }
        if isTIFFType() { return .clipyTIFF }
        return self
    }
}
