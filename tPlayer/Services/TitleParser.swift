import Foundation

enum TitleParser {
    private static let noise: Set<String> = [
        "1080p", "720p", "2160p", "480p", "4k", "uhd", "hdr", "hdr10", "hdr10+", "dv", "dovi",
        "dolby", "vision", "bluray", "blu-ray", "brrip", "bdrip", "webrip", "web-dl", "webdl",
        "web", "dl", "hdtv", "dvdrip", "dvd", "remux", "proper", "repack", "extended", "unrated",
        "limited", "x264", "x265", "h264", "h265", "hevc", "avc", "10bit", "8bit",
        "aac", "ac3", "eac3", "dts", "dts-hd", "truehd", "atmos", "5.1", "7.1", "2.0", "ddp", "dd",
        "yts", "yify", "rarbg", "eztv", "galaxyrg", "ion10", "ntb", "flux", "cmrg", "psa",
        "multi", "dual", "audio", "subs", "subbed", "dubbed", "eng", "ita", "fre", "ger", "spa"
    ]

    private static let smallWords: Set<String> = [
        "a", "an", "and", "as", "at", "but", "by", "for", "from", "in", "into",
        "nor", "of", "on", "or", "over", "the", "to", "up", "with", "yet"
    ]

    static func parse(_ filename: String) -> (title: String, year: Int?) {
        let base = (filename as NSString).deletingPathExtension
        let year = extractYear(from: base)

        var cleaned = base

        // Normalize codec spellings so "H.264" is treated like "H264".
        cleaned = cleaned.replacingOccurrences(
            of: "(?i)\\b([xh])\\.(26[45])\\b",
            with: "$1$2",
            options: .regularExpression
        )

        // Drop audio tags ("DDP5.1", "AAC2.0", "5.1") before dots become separators.
        cleaned = cleaned.replacingOccurrences(
            of: "(?i)\\b(?:ddp|dd|eac3|ac3|dts(?:-hd)?|truehd|atmos|aac)\\d?(?:\\.\\d)?\\b",
            with: " ",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: "\\b[57]\\.1\\b",
            with: " ",
            options: .regularExpression
        )

        // Bracketed and parenthesized groups carry no title information.
        cleaned = cleaned.replacingOccurrences(of: "\\[[^\\]]*\\]", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\{[^}]*\\}", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)

        // Scene release group: "…x264-GROUP", "…BluRay-GROUP", "…1080p-GROUP".
        cleaned = cleaned.replacingOccurrences(
            of: "(?i)[-._ ](?:(?:x|h)\\.?26[45]|xvid|divx|hevc|avc|bluray|blu-ray|brrip|bdrip|webrip|web-dl|webdl|hdtv|dvdrip|remux|\\d{3,4}p)[-._ ]([a-z0-9]{2,24})$",
            with: "",
            options: .regularExpression
        )

        // A fully hyphenated name ("quiet-coast") is a title, not a release tag.
        if !base.contains(where: { $0.isWhitespace || $0 == "." || $0 == "_" }) {
            cleaned = cleaned.replacingOccurrences(of: "-", with: " ")
        }

        cleaned = cleaned.replacingOccurrences(of: "[._]+", with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\s+-\\s+", with: " ", options: .regularExpression)

        let tokens = cleaned.split(whereSeparator: \.isWhitespace).map(String.init)

        // Remove only the release year, so numbers that belong to a title
        // ("2001", "1917", "Blade Runner 2049") survive.
        let yearIndex = year.flatMap { value -> Int? in
            let yearString = String(value)
            return tokens.lastIndex {
                $0.trimmingCharacters(in: .punctuationCharacters) == yearString
            }
        }

        var remaining = tokens
        if let yearIndex {
            remaining.remove(at: yearIndex)
        }

        var title = remaining.filter(isTitleToken).joined(separator: " ")
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: " -–—·,;"))

        if title.isEmpty {
            let prefix = yearIndex.map { Array(tokens[..<$0]) } ?? tokens
            title = prefix.joined(separator: " ")
                .trimmingCharacters(in: CharacterSet(charactersIn: " -–—·,;"))
        }

        if title.isEmpty {
            title = base
                .replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if title == title.lowercased() || title == title.uppercased() {
            title = titleCase(title)
        }

        return (title, year)
    }

    private static func isTitleToken(_ token: String) -> Bool {
        let t = token.lowercased().trimmingCharacters(in: .punctuationCharacters)
        guard !t.isEmpty else { return false }
        if noise.contains(t) { return false }
        if t.range(of: "^\\d{3,4}p$", options: .regularExpression) != nil { return false }
        if t.range(of: "^(x|h)\\.?26[45]$", options: .regularExpression) != nil { return false }
        if t.range(of: "^(ddp|aac|ac3|eac3|dts)\\d?(\\.\\d)?$", options: .regularExpression) != nil { return false }
        if t.range(of: "^s\\d{1,2}(e\\d{1,3})?$", options: .regularExpression) != nil { return false }
        // A codec fused to a release group survives the suffix pass when it is
        // not at the end of the name ("x264-GROUP").
        if let first = t.split(separator: "-").first,
           first.range(of: "^(x|h)\\.?26[45]$", options: .regularExpression) != nil {
            return false
        }
        return true
    }

    private static func extractYear(from string: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: "(?<!\\d)((?:19|20)\\d{2})(?!\\d)") else {
            return nil
        }
        let range = NSRange(string.startIndex..., in: string)
        let matches = regex.matches(in: string, range: range)
        let newest = (Calendar.current.component(.year, from: Date()) + 1)

        for match in matches.reversed() {
            guard let yearRange = Range(match.range(at: 1), in: string),
                  let value = Int(string[yearRange]),
                  value >= 1900, value <= newest else { continue }
            return value
        }
        return nil
    }

    private static func titleCase(_ string: String) -> String {
        let words = string.split(whereSeparator: \.isWhitespace).map(String.init)
        var result: [String] = []

        for (index, word) in words.enumerated() {
            let lower = word.lowercased()
            if index > 0, smallWords.contains(lower) {
                result.append(lower)
            } else {
                result.append(capitalize(lower))
            }
        }

        return result.joined(separator: " ")
    }

    private static func capitalize(_ word: String) -> String {
        word.split(separator: "-", omittingEmptySubsequences: false)
            .map { part -> String in
                guard let first = part.first else { return String(part) }
                return String(first).uppercased() + part.dropFirst()
            }
            .joined(separator: "-")
    }
}
