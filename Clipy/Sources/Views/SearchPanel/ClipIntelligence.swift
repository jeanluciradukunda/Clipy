//
//  ClipIntelligence.swift
//
//  Clipy
//
//  Smart clip analysis: OCR, link sanitization, content detection, snippet variables.
//

import Foundation
import Vision
import AppKit
import SwiftUI

// MARK: - OCR Service (macOS Vision Framework)

struct OCRService {
    static func recognizeText(in image: NSImage, completion: @escaping (String?) -> Void) {
        guard let tiffData = image.tiffRepresentation,
              let cgImage = NSBitmapImageRep(data: tiffData)?.cgImage else {
            completion(nil)
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let text = lines.joined(separator: "\n")
            DispatchQueue.main.async { completion(text.isEmpty ? nil : text) }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}

// MARK: - Link Sanitizer (Strip Tracking Params)

struct LinkSanitizer {
    private static let trackingParams: Set<String> = [
        // UTM
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
        // Facebook
        "fbclid", "fb_action_ids", "fb_action_types", "fb_ref", "fb_source",
        // Google
        "gclid", "gclsrc", "dclid", "gbraid", "wbraid",
        // Microsoft
        "msclkid",
        // HubSpot
        "hsa_cam", "hsa_grp", "hsa_mt", "hsa_src", "hsa_ad", "hsa_acc", "hsa_net", "hsa_ver", "hsa_la", "hsa_ol", "hsa_kw",
        // Mailchimp
        "mc_cid", "mc_eid",
        // Adobe
        "s_cid", "s_kwcid",
        // Generic tracking
        "ref", "ref_src", "ref_url", "referrer", "source",
        "_ga", "_gl", "_hsenc", "_hsmi", "_openstat",
        "yclid", "ymclid", "igshid", "si",
        // Twitter/X
        "twclid", "s", "t",
        // TikTok
        "ttclid",
        // Misc
        "mkt_tok", "trk", "trkCampaign", "sc_campaign", "sc_channel", "sc_content", "sc_medium", "sc_outcome", "sc_geo", "sc_country"
    ]

    static func sanitize(_ urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else { return nil }
        guard let queryItems = components.queryItems, !queryItems.isEmpty else { return nil }

        let cleaned = queryItems.filter { item in
            !trackingParams.contains(item.name.lowercased())
        }

        components.queryItems = cleaned.isEmpty ? nil : cleaned
        // Also strip fragment if it looks like a tracking hash (e.g. #:~:text=)
        if let fragment = components.fragment, fragment.hasPrefix(":~:") {
            components.fragment = nil
        }
        return components.string
    }

    static func hasTrackingParams(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              let queryItems = components.queryItems else { return false }
        return queryItems.contains { trackingParams.contains($0.name.lowercased()) }
    }
}

// MARK: - Content Detector (URLs, Emails, IPs, Phone Numbers)

struct DetectedContent: Identifiable {
    let id = UUID()
    let type: ContentType
    let value: String
    let range: Range<String.Index>

    enum ContentType {
        case url
        case email
        case ipAddress
        case phoneNumber

        var icon: String {
            switch self {
            case .url: return "safari"
            case .email: return "envelope"
            case .ipAddress: return "network"
            case .phoneNumber: return "phone"
            }
        }

        var label: String {
            switch self {
            case .url: return "URL"
            case .email: return "Email"
            case .ipAddress: return "IP"
            case .phoneNumber: return "Phone"
            }
        }

        var color: SwiftUI.Color {
            switch self {
            case .url: return .blue
            case .email: return .purple
            case .ipAddress: return .orange
            case .phoneNumber: return .green
            }
        }
    }
}

struct ContentDetector {
    static func detect(in text: String) -> [DetectedContent] {
        var results = [DetectedContent]()
        let nsText = text as NSString

        // URLs
        if let urlRegex = try? NSRegularExpression(pattern: "https?://[^\\s<>\"']+", options: [.caseInsensitive]) {
            let matches = urlRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let value = String(text[range])
                    // Trim trailing punctuation that's likely not part of URL
                    let cleaned = value.replacingOccurrences(of: "[).,;:!?]+$", with: "", options: .regularExpression)
                    results.append(DetectedContent(type: .url, value: cleaned, range: range))
                }
            }
        }

        // Email addresses
        if let emailRegex = try? NSRegularExpression(pattern: "[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}", options: []) {
            let matches = emailRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    results.append(DetectedContent(type: .email, value: String(text[range]), range: range))
                }
            }
        }

        // IPv4 addresses
        if let ipRegex = try? NSRegularExpression(pattern: "\\b(?:(?:25[0-5]|2[0-4]\\d|[01]?\\d\\d?)\\.){3}(?:25[0-5]|2[0-4]\\d|[01]?\\d\\d?)(?::\\d{1,5})?\\b", options: []) {
            let matches = ipRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    results.append(DetectedContent(type: .ipAddress, value: String(text[range]), range: range))
                }
            }
        }

        // Phone numbers (international format)
        if let phoneRegex = try? NSRegularExpression(pattern: "(?:\\+\\d{1,3}[\\s.-]?)?(?:\\(?\\d{2,4}\\)?[\\s.-]?)?\\d{3,4}[\\s.-]?\\d{3,4}", options: []) {
            let matches = phoneRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let value = String(text[range])
                    // Only count as phone if it has enough digits and isn't already an IP
                    let digits = value.filter(\.isNumber)
                    let isIP = results.contains { $0.type == .ipAddress && $0.value == value }
                    if digits.count >= 7 && digits.count <= 15 && !isIP {
                        results.append(DetectedContent(type: .phoneNumber, value: value, range: range))
                    }
                }
            }
        }

        return results
    }
}

// MARK: - Snippet Variable Processor

struct SnippetVariableProcessor {
    static func process(_ content: String) -> String {
        var result = content
        let now = Date()

        // Date/Time variables
        let dateFormatter = DateFormatter()

        dateFormatter.dateFormat = "yyyy-MM-dd"
        result = result.replacingOccurrences(of: "%DATE%", with: dateFormatter.string(from: now))

        dateFormatter.dateFormat = "HH:mm:ss"
        result = result.replacingOccurrences(of: "%TIME%", with: dateFormatter.string(from: now))

        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        result = result.replacingOccurrences(of: "%DATETIME%", with: dateFormatter.string(from: now))

        dateFormatter.dateFormat = "EEEE"
        result = result.replacingOccurrences(of: "%DAY%", with: dateFormatter.string(from: now))

        dateFormatter.dateFormat = "MMMM"
        result = result.replacingOccurrences(of: "%MONTH%", with: dateFormatter.string(from: now))

        dateFormatter.dateFormat = "yyyy"
        result = result.replacingOccurrences(of: "%YEAR%", with: dateFormatter.string(from: now))

        // Unix timestamp
        result = result.replacingOccurrences(of: "%TIMESTAMP%", with: "\(Int(now.timeIntervalSince1970))")

        // Clipboard content (current clipboard before snippet paste)
        if result.contains("%CLIPBOARD%") {
            let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
            result = result.replacingOccurrences(of: "%CLIPBOARD%", with: clipboard)
        }

        // UUID
        result = result.replacingOccurrences(of: "%UUID%", with: UUID().uuidString)

        // Random number
        if result.contains("%RANDOM%") {
            result = result.replacingOccurrences(of: "%RANDOM%", with: "\(Int.random(in: 1000...9999))")
        }

        return result
    }

    static let availableVariables: [(name: String, desc: String)] = [
        ("%DATE%", "Current date (yyyy-MM-dd)"),
        ("%TIME%", "Current time (HH:mm:ss)"),
        ("%DATETIME%", "Date + time"),
        ("%DAY%", "Day of the week"),
        ("%MONTH%", "Current month name"),
        ("%YEAR%", "Current year"),
        ("%TIMESTAMP%", "Unix timestamp"),
        ("%CLIPBOARD%", "Current clipboard text"),
        ("%UUID%", "Random UUID"),
        ("%RANDOM%", "Random 4-digit number")
    ]
}
