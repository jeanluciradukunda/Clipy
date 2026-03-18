// swiftlint:disable identifier_name line_length
//
//  SyntaxHighlighter.swift
//
//  Clipy
//
//  Lightweight syntax highlighting and language detection for the preview pane.
//

import SwiftUI

// MARK: - Detected Language
enum DetectedLanguage: String {
    case json = "JSON"
    case javascript = "JavaScript"
    case typescript = "TypeScript"
    case python = "Python"
    case swift = "Swift"
    case java = "Java"
    case html = "HTML"
    case css = "CSS"
    case sql = "SQL"
    case shell = "Shell"
    case ruby = "Ruby"
    case go = "Go"
    case rust = "Rust"
    case csharp = "C#"
    case cpp = "C++"
    case yaml = "YAML"
    case xml = "XML"
    case plainText = "Text"

    var icon: String {
        switch self {
        case .json: return "curlybraces"
        case .javascript, .typescript: return "chevron.left.forwardslash.chevron.right"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .swift: return "swift"
        case .java: return "cup.and.saucer"
        case .html, .xml: return "chevron.left.forwardslash.chevron.right"
        case .css: return "paintbrush"
        case .sql: return "cylinder"
        case .shell: return "terminal"
        case .ruby: return "diamond"
        case .go, .rust, .csharp, .cpp: return "chevron.left.forwardslash.chevron.right"
        case .yaml: return "list.bullet.indent"
        case .plainText: return "doc.plaintext"
        }
    }
}

// MARK: - Language Detection
struct LanguageDetector {
    static func detect(_ text: String) -> DetectedLanguage {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plainText }
        let sample = String(trimmed.prefix(2000))

        // JSON: starts with { or [ and is valid
        if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")) && isValidJSON(trimmed) {
            return .json
        }

        // HTML/XML
        if sample.hasPrefix("<!DOCTYPE") || sample.hasPrefix("<html") || sample.hasPrefix("<?xml") {
            return sample.contains("<?xml") ? .xml : .html
        }
        if sample.hasPrefix("<") && sample.contains("</") && sample.contains(">") {
            let tagCount = sample.components(separatedBy: "</").count
            if tagCount >= 3 { return .html }
        }

        // Shell
        if sample.hasPrefix("#!/") || sample.hasPrefix("#!") {
            if sample.contains("bash") || sample.contains("sh") || sample.contains("zsh") {
                return .shell
            }
            if sample.contains("python") { return .python }
            if sample.contains("ruby") { return .ruby }
            if sample.contains("node") { return .javascript }
        }

        // YAML
        if sample.contains("---\n") && !sample.contains("{") && sample.contains(": ") {
            let colonLines = sample.components(separatedBy: "\n").filter { $0.contains(": ") && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            if colonLines.count >= 3 { return .yaml }
        }

        // SQL
        let sqlKeywords = ["SELECT ", "INSERT ", "UPDATE ", "DELETE ", "CREATE TABLE", "ALTER TABLE", "DROP TABLE", "FROM ", "WHERE ", "JOIN "]
        let upperSample = sample.uppercased()
        let sqlMatches = sqlKeywords.filter { upperSample.contains($0) }.count
        if sqlMatches >= 2 { return .sql }

        // CSS
        if sample.contains("{") && sample.contains("}") && (sample.contains("color:") || sample.contains("font-") || sample.contains("margin:") || sample.contains("padding:") || sample.contains("display:") || sample.contains("@media")) {
            return .css
        }

        // TypeScript (check before JS)
        let tsIndicators = ["interface ", ": string", ": number", ": boolean", "type ", "<T>", "<T,", "as ", "readonly "]
        let tsCount = tsIndicators.filter { sample.contains($0) }.count
        if tsCount >= 2 && (sample.contains("const ") || sample.contains("let ") || sample.contains("function") || sample.contains("import ")) {
            return .typescript
        }

        // Swift
        let swiftIndicators = ["func ", "var ", "let ", "guard ", "import Foundation", "import SwiftUI", "import UIKit", "struct ", "class ", "enum ", "protocol ", "@objc", "fileprivate", "override func"]
        let swiftCount = swiftIndicators.filter { sample.contains($0) }.count
        if swiftCount >= 3 { return .swift }

        // Python
        let pyIndicators = ["def ", "import ", "from ", "class ", "self.", "print(", "elif ", "except:", "lambda ", "__init__", "    def ", "None", "True", "False"]
        let pyCount = pyIndicators.filter { sample.contains($0) }.count
        if pyCount >= 3 { return .python }

        // Java
        let javaIndicators = ["public class", "private ", "protected ", "System.out", "public static void", "import java.", "new ", "@Override", "throws ", "implements "]
        let javaCount = javaIndicators.filter { sample.contains($0) }.count
        if javaCount >= 2 { return .java }

        // Go
        let goIndicators = ["package ", "func ", "import (", "fmt.", ":= ", "go func", "chan ", "defer "]
        let goCount = goIndicators.filter { sample.contains($0) }.count
        if goCount >= 2 { return .go }

        // Rust
        let rustIndicators = ["fn ", "let mut ", "impl ", "pub fn", "use ", "mod ", "match ", "&self", "-> ", "println!"]
        let rustCount = rustIndicators.filter { sample.contains($0) }.count
        if rustCount >= 2 { return .rust }

        // C#
        let csharpIndicators = ["using System", "namespace ", "public class", "Console.", "async Task", "var ", "string ", "int "]
        let csharpCount = csharpIndicators.filter { sample.contains($0) }.count
        if csharpCount >= 2 && sample.contains("using ") { return .csharp }

        // C++
        let cppIndicators = ["#include", "std::", "cout", "cin", "iostream", "int main(", "nullptr", "template<"]
        let cppCount = cppIndicators.filter { sample.contains($0) }.count
        if cppCount >= 2 { return .cpp }

        // Ruby
        let rubyIndicators = ["def ", "end\n", "puts ", "require ", "class ", "attr_", "do |", ".each ", "nil"]
        let rubyCount = rubyIndicators.filter { sample.contains($0) }.count
        if rubyCount >= 3 { return .ruby }

        // JavaScript (broad, check last)
        let jsIndicators = ["const ", "let ", "var ", "function ", "=> ", "require(", "console.log", "document.", "export ", "import ", "async ", "await "]
        let jsCount = jsIndicators.filter { sample.contains($0) }.count
        if jsCount >= 2 { return .javascript }

        // Shell fallback
        let shellIndicators = ["echo ", "export ", "if [", "then\n", "fi\n", "done\n", "#!/", "apt ", "brew ", "npm ", "cd ", "mkdir "]
        let shellCount = shellIndicators.filter { sample.contains($0) }.count
        if shellCount >= 2 { return .shell }

        return .plainText
    }

    static func isValidJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}

// MARK: - JSON Formatter
struct JSONFormatter {
    static func prettyPrint(_ text: String) -> String? {
        guard let data = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        guard let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else { return nil }
        return String(data: pretty, encoding: .utf8)
    }

    static func minify(_ text: String) -> String? {
        guard let data = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        guard let compact = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return nil }
        return String(data: compact, encoding: .utf8)
    }
}

// MARK: - Syntax Highlighter
struct SyntaxHighlighter {
    // Theme colors as SwiftUI.Color for direct use with AttributedString
    private let cKeyword = SwiftUI.Color(red: 0.78, green: 0.46, blue: 0.85)   // purple
    private let cString = SwiftUI.Color(red: 0.91, green: 0.54, blue: 0.45)    // orange-red
    private let cNumber = SwiftUI.Color(red: 0.82, green: 0.75, blue: 0.50)    // yellow
    private let cComment = SwiftUI.Color(red: 0.45, green: 0.50, blue: 0.55)   // gray
    private let cType = SwiftUI.Color(red: 0.40, green: 0.78, blue: 0.80)      // cyan
    private let cFunction = SwiftUI.Color(red: 0.40, green: 0.70, blue: 0.95)  // blue
    private let cProperty = SwiftUI.Color(red: 0.55, green: 0.80, blue: 0.55)  // green
    private let cTag = SwiftUI.Color(red: 0.78, green: 0.46, blue: 0.85)       // purple
    private let cAttribute = SwiftUI.Color(red: 0.82, green: 0.75, blue: 0.50) // yellow

    /// Build a syntax-highlighted AttributedString for SwiftUI Text
    func highlight(_ text: String, language: DetectedLanguage, formatJSON: Bool = true) -> AttributedString {
        let source: String
        if formatJSON && language == .json, let pretty = JSONFormatter.prettyPrint(text) {
            source = pretty
        } else {
            source = text
        }

        // Limit for performance
        let toHighlight = String(source.prefix(5000))

        // Step 1: Use NSMutableAttributedString + NSRegularExpression for reliable regex matching
        // We only use this to COLLECT the ranges and their colors
        var colorRanges: [(NSRange, SwiftUI.Color)] = []

        switch language {
        case .json:       colorRanges = collectJSON(toHighlight)
        case .javascript: colorRanges = collectJS(toHighlight, isTS: false)
        case .typescript: colorRanges = collectJS(toHighlight, isTS: true)
        case .python:     colorRanges = collectPython(toHighlight)
        case .swift:      colorRanges = collectSwift(toHighlight)
        case .java:       colorRanges = collectJava(toHighlight)
        case .html, .xml: colorRanges = collectHTML(toHighlight)
        case .css:        colorRanges = collectCSS(toHighlight)
        case .sql:        colorRanges = collectSQL(toHighlight)
        case .shell:      colorRanges = collectShell(toHighlight)
        case .go:         colorRanges = collectGo(toHighlight)
        case .rust:       colorRanges = collectRust(toHighlight)
        case .ruby:       colorRanges = collectRuby(toHighlight)
        case .csharp:     colorRanges = collectCSharp(toHighlight)
        case .cpp:        colorRanges = collectCpp(toHighlight)
        case .yaml:       colorRanges = collectYAML(toHighlight)
        case .plainText:  break
        }

        // Step 2: Build SwiftUI AttributedString with the collected color ranges
        var result = AttributedString(toHighlight)
        result.font = .system(size: 12, design: .monospaced)
        result.foregroundColor = .primary.opacity(0.85)

        // Apply each color range using character offset conversion
        for (nsRange, color) in colorRanges {
            guard let stringRange = Range(nsRange, in: toHighlight) else { continue }
            let startOffset = toHighlight.distance(from: toHighlight.startIndex, to: stringRange.lowerBound)
            let length = toHighlight.distance(from: stringRange.lowerBound, to: stringRange.upperBound)
            guard length > 0 else { continue }
            let attrStart = result.characters.index(result.startIndex, offsetBy: startOffset)
            let attrEnd = result.characters.index(attrStart, offsetBy: length)
            result[attrStart..<attrEnd].foregroundColor = color
        }

        return result
    }

    // MARK: - Regex Collection Helpers

    private func matchRanges(_ text: String, pattern: String, color: SwiftUI.Color, options: NSRegularExpression.Options = []) -> [(NSRange, SwiftUI.Color)] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).map { ($0.range, color) }
    }

    // MARK: - JSON
    private func collectJSON(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #""[^"\\]*(?:\\.[^"\\]*)*"\s*:"#, color: cProperty)
        r += matchRanges(text, pattern: #":\s*"[^"\\]*(?:\\.[^"\\]*)*""#, color: cString)
        r += matchRanges(text, pattern: #"\b\d+\.?\d*\b"#, color: cNumber)
        r += matchRanges(text, pattern: #"\b(true|false|null)\b"#, color: cKeyword)
        return r
    }

    // MARK: - JavaScript / TypeScript
    private func collectJS(_ text: String, isTS: Bool) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"//[^\n]*"#, color: cComment)
        r += matchRanges(text, pattern: #"/\*[\s\S]*?\*/"#, color: cComment)
        r += matchRanges(text, pattern: #""[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*'|`[^`\\]*(?:\\.[^`\\]*)*`"#, color: cString)
        r += matchRanges(text, pattern: #"\b\d+\.?\d*\b"#, color: cNumber)
        r += matchRanges(text, pattern: #"\b(const|let|var|function|return|if|else|for|while|do|switch|case|break|continue|new|this|class|extends|import|export|from|default|async|await|try|catch|throw|finally|typeof|instanceof|in|of|yield|delete|void)\b"#, color: cKeyword)
        if isTS {
            r += matchRanges(text, pattern: #"\b(interface|type|enum|namespace|declare|readonly|as|keyof|implements|abstract|private|public|protected)\b"#, color: cKeyword)
            r += matchRanges(text, pattern: #"\b(string|number|boolean|any|void|never|unknown|undefined)\b"#, color: cType)
        }
        r += matchRanges(text, pattern: #"\b(console|document|window|Array|Object|String|Number|Boolean|Promise|Map|Set|Date|RegExp|Error|Math|JSON)\b"#, color: cType)
        return r
    }

    // MARK: - Python
    private func collectPython(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"#[^\n]*"#, color: cComment)
        r += matchRanges(text, pattern: #"(\"\"\"[\s\S]*?\"\"\"|'''[\s\S]*?''')"#, color: cString)
        r += matchRanges(text, pattern: #""[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*'"#, color: cString)
        r += matchRanges(text, pattern: #"\b\d+\.?\d*\b"#, color: cNumber)
        r += matchRanges(text, pattern: #"\b(def|class|import|from|return|if|elif|else|for|while|with|as|try|except|finally|raise|pass|break|continue|and|or|not|in|is|lambda|yield|global|nonlocal|assert|del|True|False|None|async|await|self)\b"#, color: cKeyword)
        r += matchRanges(text, pattern: #"\b(print|len|range|int|str|float|list|dict|tuple|set|bool|type|isinstance|enumerate|zip|map|filter|sorted|reversed|super|property|staticmethod|classmethod)\b"#, color: cFunction)
        return r
    }

    // MARK: - Swift
    private func collectSwift(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"//[^\n]*"#, color: cComment)
        r += matchRanges(text, pattern: #"/\*[\s\S]*?\*/"#, color: cComment)
        r += matchRanges(text, pattern: #""[^"\\]*(?:\\.[^"\\]*)*""#, color: cString)
        r += matchRanges(text, pattern: #"\b\d+\.?\d*\b"#, color: cNumber)
        r += matchRanges(text, pattern: #"\b(import|func|var|let|class|struct|enum|protocol|extension|if|else|guard|switch|case|for|while|repeat|return|break|continue|throw|throws|try|catch|do|in|where|as|is|self|Self|super|init|deinit|nil|true|false|typealias|associatedtype|some|any|async|await|actor|override|final|static|private|fileprivate|internal|public|open|weak|unowned|lazy|mutating|inout|defer|subscript|willSet|didSet|get|set)\b"#, color: cKeyword)
        r += matchRanges(text, pattern: #"\b(String|Int|Double|Float|Bool|Array|Dictionary|Set|Optional|Result|Error|Void|Any|AnyObject|Date|URL|Data|Task)\b"#, color: cType)
        r += matchRanges(text, pattern: #"@\w+"#, color: cAttribute)
        return r
    }

    // MARK: - Java
    private func collectJava(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"//[^\n]*"#, color: cComment)
        r += matchRanges(text, pattern: #"/\*[\s\S]*?\*/"#, color: cComment)
        r += matchRanges(text, pattern: #""[^"\\]*(?:\\.[^"\\]*)*""#, color: cString)
        r += matchRanges(text, pattern: #"\b\d+\.?\d*[fFdDlL]?\b"#, color: cNumber)
        r += matchRanges(text, pattern: #"\b(abstract|assert|break|case|catch|class|continue|default|do|else|enum|extends|final|finally|for|if|implements|import|instanceof|interface|native|new|package|private|protected|public|return|static|strictfp|super|switch|synchronized|this|throw|throws|transient|try|void|volatile|while|var|record|sealed|permits|true|false|null)\b"#, color: cKeyword)
        r += matchRanges(text, pattern: #"\b(String|Integer|Boolean|Long|Double|Float|List|Map|Set|ArrayList|HashMap|HashSet|Optional|Stream|Object|System|Class)\b"#, color: cType)
        r += matchRanges(text, pattern: #"@\w+"#, color: cAttribute)
        return r
    }

    // MARK: - HTML/XML
    private func collectHTML(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"<!--[\s\S]*?-->"#, color: cComment)
        r += matchRanges(text, pattern: #"</?[a-zA-Z][a-zA-Z0-9]*"#, color: cTag)
        r += matchRanges(text, pattern: #"\s[a-zA-Z\-]+="#, color: cAttribute)
        r += matchRanges(text, pattern: #""[^"]*"|'[^']*'"#, color: cString)
        r += matchRanges(text, pattern: #"/?\s*>"#, color: cTag)
        return r
    }

    // MARK: - CSS
    private func collectCSS(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"/\*[\s\S]*?\*/"#, color: cComment)
        r += matchRanges(text, pattern: #"[.#]?[a-zA-Z_][\w\-]*\s*\{"#, color: cTag)
        r += matchRanges(text, pattern: #"[\w\-]+\s*:"#, color: cProperty)
        r += matchRanges(text, pattern: #""[^"]*"|'[^']*'"#, color: cString)
        r += matchRanges(text, pattern: #"\b\d+\.?\d*(px|em|rem|%|vh|vw|pt|s|ms)?\b"#, color: cNumber)
        r += matchRanges(text, pattern: #"#[0-9a-fA-F]{3,8}\b"#, color: cNumber)
        r += matchRanges(text, pattern: #"@(media|keyframes|import|font-face|supports)\b"#, color: cKeyword)
        return r
    }

    // MARK: - SQL
    private func collectSQL(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"--[^\n]*"#, color: cComment)
        r += matchRanges(text, pattern: #"'[^']*'"#, color: cString)
        r += matchRanges(text, pattern: #"\b\d+\.?\d*\b"#, color: cNumber)
        r += matchRanges(text, pattern: #"(?i)\b(SELECT|FROM|WHERE|INSERT|INTO|VALUES|UPDATE|SET|DELETE|CREATE|TABLE|ALTER|DROP|INDEX|JOIN|INNER|LEFT|RIGHT|OUTER|ON|AND|OR|NOT|IN|IS|NULL|AS|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|EXISTS|BETWEEN|LIKE|CASE|WHEN|THEN|ELSE|END|COUNT|SUM|AVG|MAX|MIN|PRIMARY|KEY|FOREIGN|REFERENCES|CONSTRAINT|DEFAULT|CHECK|UNIQUE|CASCADE|VIEW|TRIGGER|PROCEDURE|FUNCTION|BEGIN|COMMIT|ROLLBACK)\b"#, color: cKeyword)
        return r
    }

    // MARK: - Shell
    private func collectShell(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"#[^\n]*"#, color: cComment)
        r += matchRanges(text, pattern: #""[^"\\]*(?:\\.[^"\\]*)*"|'[^']*'"#, color: cString)
        r += matchRanges(text, pattern: #"\$\{?\w+\}?"#, color: cProperty)
        r += matchRanges(text, pattern: #"\b(if|then|else|elif|fi|for|do|done|while|until|case|esac|in|function|return|exit|local|export|source|alias|unalias|set|unset|readonly|shift|trap)\b"#, color: cKeyword)
        r += matchRanges(text, pattern: #"\b(echo|cd|ls|cat|grep|sed|awk|find|xargs|sort|uniq|wc|head|tail|cut|tr|chmod|chown|mkdir|rm|cp|mv|ln|curl|wget|git|docker|npm|pip|brew|apt|sudo)\b"#, color: cFunction)
        return r
    }

    // MARK: - Go
    private func collectGo(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"//[^\n]*"#, color: cComment)
        r += matchRanges(text, pattern: #"/\*[\s\S]*?\*/"#, color: cComment)
        r += matchRanges(text, pattern: #""[^"\\]*(?:\\.[^"\\]*)*"|`[^`]*`"#, color: cString)
        r += matchRanges(text, pattern: #"\b\d+\.?\d*\b"#, color: cNumber)
        r += matchRanges(text, pattern: #"\b(package|import|func|var|const|type|struct|interface|map|chan|go|select|case|default|if|else|for|range|switch|return|break|continue|defer|fallthrough|goto|nil|true|false|iota)\b"#, color: cKeyword)
        r += matchRanges(text, pattern: #"\b(string|int|int64|float64|bool|byte|rune|error|any)\b"#, color: cType)
        r += matchRanges(text, pattern: #"\b(fmt|log|os|io|net|http|json|strings|strconv|sync|context|errors|time)\b"#, color: cType)
        return r
    }

    // MARK: - Rust
    private func collectRust(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"//[^\n]*"#, color: cComment)
        r += matchRanges(text, pattern: #"/\*[\s\S]*?\*/"#, color: cComment)
        r += matchRanges(text, pattern: #""[^"\\]*(?:\\.[^"\\]*)*""#, color: cString)
        r += matchRanges(text, pattern: #"\b\d+\.?\d*\b"#, color: cNumber)
        r += matchRanges(text, pattern: #"\b(fn|let|mut|const|struct|enum|impl|trait|pub|use|mod|crate|super|self|Self|if|else|match|for|while|loop|in|return|break|continue|where|as|ref|move|async|await|dyn|static|extern|type|unsafe|true|false)\b"#, color: cKeyword)
        r += matchRanges(text, pattern: #"\b(String|Vec|Option|Result|Box|Rc|Arc|HashMap|HashSet|i32|i64|u32|u64|f64|f32|bool|str|usize|isize)\b"#, color: cType)
        r += matchRanges(text, pattern: #"\b\w+!"#, color: cFunction)
        return r
    }

    // MARK: - Ruby
    private func collectRuby(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"#[^\n]*"#, color: cComment)
        r += matchRanges(text, pattern: #""[^"\\]*(?:\\.[^"\\]*)*"|'[^'\\]*(?:\\.[^'\\]*)*'"#, color: cString)
        r += matchRanges(text, pattern: #"\b\d+\.?\d*\b"#, color: cNumber)
        r += matchRanges(text, pattern: #":[a-zA-Z_]\w*"#, color: cProperty)
        r += matchRanges(text, pattern: #"\b(def|class|module|end|if|elsif|else|unless|case|when|while|until|for|do|begin|rescue|ensure|raise|return|yield|block_given\?|require|include|extend|attr_accessor|attr_reader|attr_writer|private|protected|public|self|super|nil|true|false|and|or|not|in|then)\b"#, color: cKeyword)
        return r
    }

    // MARK: - C#
    private func collectCSharp(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"//[^\n]*"#, color: cComment)
        r += matchRanges(text, pattern: #"/\*[\s\S]*?\*/"#, color: cComment)
        r += matchRanges(text, pattern: #""[^"\\]*(?:\\.[^"\\]*)*""#, color: cString)
        r += matchRanges(text, pattern: #"\b\d+\.?\d*[fFdDmM]?\b"#, color: cNumber)
        r += matchRanges(text, pattern: #"\b(using|namespace|class|struct|enum|interface|abstract|sealed|static|partial|public|private|protected|internal|virtual|override|new|void|return|if|else|for|foreach|while|do|switch|case|break|continue|try|catch|finally|throw|async|await|var|const|readonly|ref|out|in|is|as|typeof|true|false|null|this|base|yield|delegate|event|lock|params|where|get|set|value|init)\b"#, color: cKeyword)
        r += matchRanges(text, pattern: #"\b(string|int|long|double|float|bool|byte|char|decimal|object|dynamic|List|Dictionary|Task|IEnumerable|Action|Func|Tuple|Nullable|Console|String|Array|Object)\b"#, color: cType)
        return r
    }

    // MARK: - C++
    private func collectCpp(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"//[^\n]*"#, color: cComment)
        r += matchRanges(text, pattern: #"/\*[\s\S]*?\*/"#, color: cComment)
        r += matchRanges(text, pattern: #"#\w+[^\n]*"#, color: cAttribute)
        r += matchRanges(text, pattern: #""[^"\\]*(?:\\.[^"\\]*)*""#, color: cString)
        r += matchRanges(text, pattern: #"\b\d+\.?\d*[fFlL]?\b"#, color: cNumber)
        r += matchRanges(text, pattern: #"\b(auto|break|case|class|const|continue|default|delete|do|else|enum|extern|for|friend|goto|if|inline|mutable|namespace|new|noexcept|operator|private|protected|public|register|return|sizeof|static|struct|switch|template|this|throw|try|catch|typedef|typeid|typename|union|using|virtual|void|volatile|while|override|final|nullptr|true|false|constexpr|decltype|static_assert|thread_local|co_await|co_return|co_yield|concept|requires)\b"#, color: cKeyword)
        r += matchRanges(text, pattern: #"\b(int|long|short|char|float|double|bool|unsigned|signed|size_t|string|vector|map|set|pair|unique_ptr|shared_ptr|optional|variant|tuple|array)\b"#, color: cType)
        r += matchRanges(text, pattern: #"\bstd::\w+"#, color: cType)
        return r
    }

    // MARK: - YAML
    private func collectYAML(_ text: String) -> [(NSRange, SwiftUI.Color)] {
        var r: [(NSRange, SwiftUI.Color)] = []
        r += matchRanges(text, pattern: #"#[^\n]*"#, color: cComment)
        r += matchRanges(text, pattern: #"^[\w\-\.]+:"#, color: cProperty, options: .anchorsMatchLines)
        r += matchRanges(text, pattern: #"^\s+[\w\-\.]+:"#, color: cProperty, options: .anchorsMatchLines)
        r += matchRanges(text, pattern: #""[^"]*"|'[^']*'"#, color: cString)
        r += matchRanges(text, pattern: #"\b\d+\.?\d*\b"#, color: cNumber)
        r += matchRanges(text, pattern: #"\b(true|false|null|yes|no|on|off)\b"#, color: cKeyword)
        return r
    }
}
