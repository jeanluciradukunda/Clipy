//
//  CPYClipData.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//
//  Created by Econa77 on 2015/06/21.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import CryptoKit

final class CPYClipData: NSObject {

    // MARK: - Properties
    fileprivate let kTypesKey       = "types"
    fileprivate let kStringValueKey = "stringValue"
    fileprivate let kRTFDataKey     = "RTFData"
    fileprivate let kPDFKey         = "PDF"
    fileprivate let kFileNamesKey   = "filenames"
    fileprivate let kURLsKey        = "URL"
    fileprivate let kImageKey       = "image"

    var types          = [NSPasteboard.PasteboardType]()
    var fileNames      = [String]()
    var URLs           = [String]()
    var stringValue    = ""
    var RTFData: Data?
    var PDF: Data?
    var image: NSImage?

    private var cachedKeys: (hash: Int, legacyHash: Int?)?

    /// The clip's primary key: a digest of everything the clip holds, so two clips share a key only
    /// when their content matches. Images contribute a digest of their pixels, so a re-encoded copy
    /// (a clip pasted back from history) keeps its key. Rendering is expensive, so call
    /// `prepareKeys()` off the main thread before the first read.
    override var hash: Int {
        return prepareKeys().hash
    }

    /// The key earlier releases gave this clip, built from sampled string hashes and byte counts,
    /// so different clips could share it. Used to find a clip saved before upgrading.
    var legacyHash: Int? {
        return prepareKeys().legacyHash
    }

    @discardableResult
    func prepareKeys() -> (hash: Int, legacyHash: Int?) {
        if let cachedKeys = cachedKeys { return cachedKeys }
        let imageData = image?.tiffRepresentation
        let keys = (hash: contentDigest(imageData: imageData), legacyHash: legacyKey(imageByteCount: imageData?.count) as Int?)
        cachedKeys = keys
        return keys
    }

    private func contentDigest(imageData: Data?) -> Int {
        var hasher = SHA256()
        func add(_ part: String, _ data: Data?) {
            guard let data = data else { return }
            hasher.update(data: Data("\(part):\(data.count):".utf8))
            hasher.update(data: data)
        }
        add("types", Data(types.map { $0.rawValue }.joined(separator: "\n").utf8))
        if let image = image {
            let pixels = Self.pixelDigest(of: image) ?? imageData.map { Self.digest(of: $0) } ?? 0
            add("image", withUnsafeBytes(of: pixels) { Data($0) })
        }
        add("files", fileNames.isEmpty ? nil : Data(fileNames.joined(separator: "\n").utf8))
        add("urls", URLs.isEmpty ? nil : Data(URLs.joined(separator: "\n").utf8))
        add("pdf", PDF)
        add("string", stringValue.isEmpty ? nil : Data(stringValue.utf8))
        add("rtf", RTFData)
        return hasher.finalize().withUnsafeBytes { $0.loadUnaligned(as: Int.self) }
    }

    private func legacyKey(imageByteCount: Int?) -> Int {
        var hash = types.map { $0.rawValue }.joined().hash
        if let byteCount = imageByteCount {
            hash ^= byteCount
        } else if let image = self.image {
            hash ^= image.hash
        }
        if !fileNames.isEmpty {
            fileNames.forEach { hash ^= $0.hash }
        } else if !self.URLs.isEmpty {
            URLs.forEach { hash ^= $0.hash }
        } else if let pdf = PDF {
            hash ^= pdf.count
        } else if !stringValue.isEmpty {
            hash ^= stringValue.hash
        }
        if let data = RTFData {
            hash ^= data.count
        }
        return hash
    }

    static func digest(of data: Data) -> Int {
        return SHA256.hash(data: data).withUnsafeBytes { $0.loadUnaligned(as: Int.self) }
    }

    static func pixelDigest(of image: NSImage) -> Int? {
        let bitmap = image.representations.lazy.compactMap { $0 as? NSBitmapImageRep }.first
        guard let cgImage = bitmap?.cgImage ?? image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let width = cgImage.width, height = cgImage.height
        var pixels = Data(count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: sRGB,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var hasher = SHA256()
        hasher.update(data: Data("\(width)x\(height)".utf8))
        hasher.update(data: pixels)
        return hasher.finalize().withUnsafeBytes { $0.loadUnaligned(as: Int.self) }
    }

    var primaryType: NSPasteboard.PasteboardType? {
        return types.first
    }
    var isOnlyStringType: Bool {
        return types.count == 1 && (types.first?.isStringType() ?? false)
    }
    var thumbnailImage: NSImage? {
        let defaults = AppEnvironment.current.defaults
        let width = defaults.integer(forKey: Constants.UserDefaults.thumbnailWidth)
        let height = defaults.integer(forKey: Constants.UserDefaults.thumbnailHeight)

        if let image = image, fileNames.isEmpty {
            return image.resizeImage(CGFloat(width), CGFloat(height))
        } else if let fileName = fileNames.first, let path = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let url = URL(string: path) {
            switch url.pathExtension.lowercased() {
            case "jpg", "jpeg", "png", "bmp", "tiff", "webp", "heic":
                return NSImage(contentsOfFile: fileName)?.resizeImage(CGFloat(width), CGFloat(height))
            default: break
            }
        }
        return nil
    }
    var colorCodeImage: NSImage? {
        guard let color = NSColor(hexString: stringValue) else { return nil }
        return NSImage.create(with: color, size: NSSize(width: 20, height: 20))
    }

    static var availableTypes: [NSPasteboard.PasteboardType] {
        return [.clipyString,
                .clipyRTF,
                .clipyRTFD,
                .clipyPDF,
                .clipyFilenames,
                .clipyURL,
                .clipyTIFF]
    }
    static var availableTypesString: [String] {
        return ["String",
                "RTF",
                "RTFD",
                "PDF",
                "Filenames",
                "URL",
                "TIFF"]
    }
    static var availableTypesDictinary: [NSPasteboard.PasteboardType: String] {
        var availableTypes = [NSPasteboard.PasteboardType: String]()
        zip(CPYClipData.availableTypes, CPYClipData.availableTypesString).forEach { availableTypes[$0] = $1 }
        // Also map legacy types for backward compatibility
        let legacyTypes: [NSPasteboard.PasteboardType] = [.legacyString, .legacyRTF, .legacyRTFD, .legacyPDF, .legacyFilenames, .legacyURL, .legacyTIFF]
        zip(legacyTypes, CPYClipData.availableTypesString).forEach { availableTypes[$0] = $1 }
        return availableTypes
    }

    // MARK: - Init
    init(pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) {
        super.init()
        self.types = types
        types.forEach { type in
            if type.isStringType() {
                guard let string = pasteboard.string(forType: type) else { return }
                stringValue = string
            } else if type.isRTFDType() {
                RTFData = pasteboard.data(forType: type)
            } else if type.isRTFType() && RTFData == nil {
                RTFData = pasteboard.data(forType: type)
            } else if type.isPDFType() {
                PDF = pasteboard.data(forType: type)
            } else if type.isFilenamesType() {
                // Support both modern fileURL and legacy filenames
                if let filenames = pasteboard.propertyList(forType: type) as? [String] {
                    self.fileNames = filenames
                } else if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
                    self.fileNames = urls.map { $0.path }
                }
            } else if type.isURLType() {
                if let urls = pasteboard.propertyList(forType: type) as? [String] {
                    URLs = urls
                }
            } else if type.isTIFFType() {
                image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage
            }
        }
    }

    init(image: NSImage) {
        self.types = [.clipyTIFF]
        self.image = image
    }

    deinit {
        self.RTFData = nil
        self.PDF = nil
        self.image = nil
    }

    // MARK: - NSCoding
    @objc func encodeWithCoder(_ aCoder: NSCoder) {
        aCoder.encode(types.map { $0.rawValue }, forKey: kTypesKey)
        aCoder.encode(stringValue, forKey: kStringValueKey)
        aCoder.encode(RTFData, forKey: kRTFDataKey)
        aCoder.encode(PDF, forKey: kPDFKey)
        aCoder.encode(fileNames, forKey: kFileNamesKey)
        aCoder.encode(URLs, forKey: kURLsKey)
        aCoder.encode(image, forKey: kImageKey)
    }

    @objc required init(coder aDecoder: NSCoder) {
        types = (aDecoder.decodeObject(forKey: kTypesKey) as? [String])?.compactMap { NSPasteboard.PasteboardType(rawValue: $0) } ?? []
        fileNames = aDecoder.decodeObject(forKey: kFileNamesKey) as? [String] ?? [String]()
        URLs = aDecoder.decodeObject(forKey: kURLsKey) as? [String] ?? [String]()
        stringValue = aDecoder.decodeObject(forKey: kStringValueKey) as? String ?? ""
        RTFData = aDecoder.decodeObject(forKey: kRTFDataKey) as? Data
        PDF = aDecoder.decodeObject(forKey: kPDFKey) as? Data
        image = aDecoder.decodeObject(forKey: kImageKey) as? NSImage
        super.init()
    }
}
