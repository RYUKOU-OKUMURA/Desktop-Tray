import SwiftUI

/// トレイ一覧の名前変更・削除・新規作成を行う管理画面（Fix H）。
struct TrayManagementView: View {
    let trays: [TrayManagementRow]
    let onRename: (UUID, String) -> Void
    let onDelete: (UUID) -> Void
    let onCreateTray: () -> Void

    @State private var editingID: UUID?
    @State private var editingName: String = ""
    @State private var pendingDeleteID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("tray.management.title", comment: ""))
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)

            List {
                ForEach(trays) { row in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(row.color.swiftUIColor)
                            .frame(width: 10, height: 10)

                        if editingID == row.id {
                            TextField(
                                NSLocalizedString("tray.rename.placeholder", comment: ""),
                                text: $editingName,
                                onCommit: { commitRename(for: row.id) }
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 160)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.name)
                                    .font(.body.weight(.medium))
                                Text(row.typeLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text("\(row.itemCount)\(NSLocalizedString("tray.count.suffix", comment: ""))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)

                        if editingID == row.id {
                            Button(NSLocalizedString("tray.rename.save", comment: "")) {
                                commitRename(for: row.id)
                            }
                        } else {
                            Button(NSLocalizedString("tray.rename", comment: "")) {
                                startEditing(row)
                            }
                        }

                        Button(role: .destructive) {
                            pendingDeleteID = row.id
                        } label: {
                            Text(NSLocalizedString("tray.delete", comment: ""))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)

            HStack {
                Button(action: onCreateTray) {
                    Label(NSLocalizedString("tray.management.add", comment: ""), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(20)
        }
        .frame(minWidth: 560, minHeight: 420)
        .alert(
            NSLocalizedString("tray.delete.confirm.title", comment: ""),
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { if !$0 { pendingDeleteID = nil } }
            ),
            presenting: pendingDeleteID
        ) { id in
            Button(NSLocalizedString("tray.delete", comment: ""), role: .destructive) {
                onDelete(id)
                pendingDeleteID = nil
            }
            Button(NSLocalizedString("tray.delete.cancel", comment: ""), role: .cancel) {
                pendingDeleteID = nil
            }
        } message: { _ in
            Text(NSLocalizedString("tray.delete.confirm.message", comment: ""))
        }
    }

    private func startEditing(_ row: TrayManagementRow) {
        editingID = row.id
        editingName = row.name
    }

    private func commitRename(for id: UUID) {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onRename(id, trimmed)
        editingID = nil
        editingName = ""
    }
}

struct TrayManagementRow: Identifiable, Equatable {
    let id: UUID
    let name: String
    let color: TrayColor
    let itemCount: Int
    let isSmart: Bool

    var typeLabel: String {
        isSmart
            ? NSLocalizedString("tray.management.type.smart", comment: "")
            : NSLocalizedString("tray.management.type.manual", comment: "")
    }
}
