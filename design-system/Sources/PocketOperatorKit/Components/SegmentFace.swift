import SwiftUI

/// The glyph set a segment display is wired for.
///
/// A real display's character repertoire is a property of its *hardware*, not
/// of the text you send it: a seven-segment panel physically cannot form a K,
/// and a product that needs arbitrary words has to specify a dot-matrix part
/// instead. Modelling that as a value — rather than silently rendering
/// whatever happens to be in a dictionary — means a product can validate its
/// strings against the display it chose, at build time or in a test.
public struct SegmentFace: Sendable, Equatable {

    public enum Kind: Sendable, Equatable {
        /// Seven bars per cell. Fast to read for digits, lossy for letters.
        case sevenSegment
        /// A 5x7 dot lattice per cell. Renders any Latin character legibly.
        case dotMatrix
    }

    public let kind: Kind
    /// Bitmask per character: bit 0 top, 1 top-right, 2 bottom-right,
    /// 3 bottom, 4 bottom-left, 5 top-left, 6 middle.
    public let sevenSegmentGlyphs: [Character: UInt8]
    /// Seven rows of five bits per character, most significant bit leftmost.
    public let dotMatrixGlyphs: [Character: [UInt8]]

    public init(
        kind: Kind,
        sevenSegmentGlyphs: [Character: UInt8] = [:],
        dotMatrixGlyphs: [Character: [UInt8]] = [:]
    ) {
        self.kind = kind
        self.sevenSegmentGlyphs = sevenSegmentGlyphs
        self.dotMatrixGlyphs = dotMatrixGlyphs
    }

    /// Standard seven-segment repertoire: digits, punctuation, and the letters
    /// a seven-bar cell can form without becoming ambiguous.
    public static let sevenSegment = SegmentFace(
        kind: .sevenSegment,
        sevenSegmentGlyphs: SevenSegmentGlyphs.standard
    )

    /// Standard 5x7 dot-matrix repertoire: full digits and A-Z plus common
    /// punctuation.
    public static let dotMatrix = SegmentFace(
        kind: .dotMatrix,
        dotMatrixGlyphs: DotMatrixGlyphs.standard
    )

    /// Whether this face can form `character`.
    public func supports(_ character: Character) -> Bool {
        let upper = Character(character.uppercased())
        if upper == " " { return true }
        return switch kind {
        case .sevenSegment: sevenSegmentGlyphs[upper] != nil
        case .dotMatrix: dotMatrixGlyphs[upper] != nil
        }
    }

    /// Characters in `text` this face cannot form; empty means the string is
    /// safe to display as written.
    ///
    /// Worth asserting on in a test for any string that ships — a display
    /// silently dropping half a status word is the kind of defect that only
    /// shows up in a screenshot.
    public func unsupportedCharacters(in text: String) -> [Character] {
        text.filter { !supports($0) }
    }

    /// A copy of this face with extra or replacement glyphs.
    ///
    /// The escape hatch for a product with its own symbols — a battery icon
    /// cell, a degree sign, a bespoke logotype glyph.
    public func overriding(sevenSegment additions: [Character: UInt8]) -> SegmentFace {
        SegmentFace(
            kind: kind,
            sevenSegmentGlyphs: sevenSegmentGlyphs.merging(additions) { _, new in new },
            dotMatrixGlyphs: dotMatrixGlyphs
        )
    }

    public func overriding(dotMatrix additions: [Character: [UInt8]]) -> SegmentFace {
        SegmentFace(
            kind: kind,
            sevenSegmentGlyphs: sevenSegmentGlyphs,
            dotMatrixGlyphs: dotMatrixGlyphs.merging(additions) { _, new in new }
        )
    }
}

/// Seven-segment bit patterns.
///
/// Letters that a seven-bar cell cannot distinguish (K, X, W) borrow the
/// closest form rather than blanking, matching what real panels do — but this
/// is why `SegmentFace.dotMatrix` exists, and why any user-supplied text
/// should use it.
public enum SevenSegmentGlyphs {
    public static let standard: [Character: UInt8] = [
        "0": 0b0111111, "1": 0b0000110, "2": 0b1011011, "3": 0b1001111,
        "4": 0b1100110, "5": 0b1101101, "6": 0b1111101, "7": 0b0000111,
        "8": 0b1111111, "9": 0b1101111,
        "-": 0b1000000, "_": 0b0001000, "=": 0b1001000, "'": 0b0100000,
        "\"": 0b0100010, "[": 0b0111001, "]": 0b0001111, "(": 0b0111001,
        ")": 0b0001111, "°": 0b1100011, "?": 0b1010011,
        "A": 0b1110111, "B": 0b1111100, "C": 0b0111001, "D": 0b1011110,
        "E": 0b1111001, "F": 0b1110001, "G": 0b0111101, "H": 0b1110110,
        "I": 0b0000110, "J": 0b0011110, "K": 0b1110110, "L": 0b0111000,
        "M": 0b0110111, "N": 0b1010100, "O": 0b0111111, "P": 0b1110011,
        "Q": 0b1100111, "R": 0b1010000, "S": 0b1101101, "T": 0b1111000,
        "U": 0b0111110, "V": 0b0011100, "W": 0b0111110, "X": 0b1110110,
        "Y": 0b1101110, "Z": 0b1011011,
    ]
}

/// 5x7 dot-matrix font, seven rows of five bits, bit 4 leftmost.
public enum DotMatrixGlyphs {
    public static let standard: [Character: [UInt8]] = [
        "0": [0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110],
        "1": [0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
        "2": [0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b01000, 0b11111],
        "3": [0b11111, 0b00010, 0b00100, 0b00010, 0b00001, 0b10001, 0b01110],
        "4": [0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010],
        "5": [0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110],
        "6": [0b00110, 0b01000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110],
        "7": [0b11111, 0b10001, 0b00001, 0b00010, 0b00100, 0b00100, 0b00100],
        "8": [0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110],
        "9": [0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00010, 0b01100],
        "A": [0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
        "B": [0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110],
        "C": [0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110],
        "D": [0b11100, 0b10010, 0b10001, 0b10001, 0b10001, 0b10010, 0b11100],
        "E": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111],
        "F": [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000],
        "G": [0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01111],
        "H": [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
        "I": [0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
        "J": [0b00111, 0b00010, 0b00010, 0b00010, 0b00010, 0b10010, 0b01100],
        "K": [0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001],
        "L": [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111],
        "M": [0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001],
        "N": [0b10001, 0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001],
        "O": [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
        "P": [0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000],
        "Q": [0b01110, 0b10001, 0b10001, 0b10001, 0b10101, 0b10010, 0b01101],
        "R": [0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001],
        "S": [0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110],
        "T": [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100],
        "U": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
        "V": [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100],
        "W": [0b10001, 0b10001, 0b10001, 0b10101, 0b10101, 0b11011, 0b10001],
        "X": [0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001],
        "Y": [0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100],
        "Z": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b10000, 0b11111],
        "-": [0b00000, 0b00000, 0b00000, 0b11111, 0b00000, 0b00000, 0b00000],
        "_": [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b11111],
        ".": [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b01100, 0b01100],
        ",": [0b00000, 0b00000, 0b00000, 0b00000, 0b01100, 0b00100, 0b01000],
        ":": [0b00000, 0b01100, 0b01100, 0b00000, 0b01100, 0b01100, 0b00000],
        "/": [0b00001, 0b00010, 0b00010, 0b00100, 0b01000, 0b01000, 0b10000],
        "\\": [0b10000, 0b01000, 0b01000, 0b00100, 0b00010, 0b00010, 0b00001],
        "+": [0b00000, 0b00100, 0b00100, 0b11111, 0b00100, 0b00100, 0b00000],
        "=": [0b00000, 0b00000, 0b11111, 0b00000, 0b11111, 0b00000, 0b00000],
        "<": [0b00010, 0b00100, 0b01000, 0b10000, 0b01000, 0b00100, 0b00010],
        ">": [0b01000, 0b00100, 0b00010, 0b00001, 0b00010, 0b00100, 0b01000],
        "(": [0b00010, 0b00100, 0b01000, 0b01000, 0b01000, 0b00100, 0b00010],
        ")": [0b01000, 0b00100, 0b00010, 0b00010, 0b00010, 0b00100, 0b01000],
        "[": [0b01110, 0b01000, 0b01000, 0b01000, 0b01000, 0b01000, 0b01110],
        "]": [0b01110, 0b00010, 0b00010, 0b00010, 0b00010, 0b00010, 0b01110],
        "*": [0b00000, 0b10101, 0b01110, 0b11111, 0b01110, 0b10101, 0b00000],
        "%": [0b11000, 0b11001, 0b00010, 0b00100, 0b01000, 0b10011, 0b00011],
        "#": [0b01010, 0b01010, 0b11111, 0b01010, 0b11111, 0b01010, 0b01010],
        "!": [0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00000, 0b00100],
        "?": [0b01110, 0b10001, 0b00001, 0b00010, 0b00100, 0b00000, 0b00100],
        "'": [0b00100, 0b00100, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000],
        "°": [0b01100, 0b10010, 0b01100, 0b00000, 0b00000, 0b00000, 0b00000],
    ]
}
