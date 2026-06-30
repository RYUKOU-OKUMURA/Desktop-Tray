import CoreTransferable
import Foundation

/// トレイアイテムのドラッグ＆ドロップ用転送データ（Fix F）。
/// トレイ内並び替えとトレイ間移動の両方で使う。`.json` を contentType に使い、
/// カスタム UTType 宣言なしでアプリ内 D&D を実現する。
struct TrayItemTransfer: Codable, Transferable, Sendable, Equatable {
    let itemID: UUID
    let sourceTrayID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
