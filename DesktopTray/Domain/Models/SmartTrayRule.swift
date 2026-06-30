import Foundation

/// スマートトレイのルール型。MVP プリセットのみ（要件定義 §9.2 / アーキテクチャ v0.1 §6.1）。
/// 条件編集 UI は MVP 以降のため、本型は表示用パラメータを持たない。
enum SmartRuleKind: Codable, Sendable, Equatable, Hashable {
    /// ファイル名に指定文字列群のいずれかを含む（大文字小文字区別なし）。
    /// スクリーンショットプリセットのように OR 条件を表現できるよう配列で持つ。
    case filenameContainsAny([String])
    /// 拡張子が指定群のいずれか（小文字統一で比較）。
    case fileExtensionIn([String])
    /// 作成日 or 追加日が N 日以内。
    case createdWithinDays(Int)
    /// 未分類。手動未所属 かつ 他スマートルール非該当。
    case uncategorized

    private enum CodingKeys: String, CodingKey {
        case kind
        case values
        case extensions
        case days
    }

    private enum KindTag: String, Codable {
        case filenameContainsAny
        case fileExtensionIn
        case createdWithinDays
        case uncategorized
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let tag = try c.decode(KindTag.self, forKey: .kind)
        switch tag {
        case .filenameContainsAny:
            let values = try c.decode([String].self, forKey: .values)
            self = .filenameContainsAny(values)
        case .fileExtensionIn:
            let exts = try c.decode([String].self, forKey: .extensions)
            self = .fileExtensionIn(exts)
        case .createdWithinDays:
            let days = try c.decode(Int.self, forKey: .days)
            self = .createdWithinDays(days)
        case .uncategorized:
            self = .uncategorized
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .filenameContainsAny(let values):
            try c.encode(KindTag.filenameContainsAny, forKey: .kind)
            try c.encode(values, forKey: .values)
        case .fileExtensionIn(let exts):
            try c.encode(KindTag.fileExtensionIn, forKey: .kind)
            try c.encode(exts, forKey: .extensions)
        case .createdWithinDays(let days):
            try c.encode(KindTag.createdWithinDays, forKey: .kind)
            try c.encode(days, forKey: .days)
        case .uncategorized:
            try c.encode(KindTag.uncategorized, forKey: .kind)
        }
    }
}

/// スマートトレイのルール定義。`Tray.rule` に格納される。
struct SmartTrayRule: Codable, Sendable, Equatable, Hashable {
    var kind: SmartRuleKind

    init(kind: SmartRuleKind) {
        self.kind = kind
    }
}
