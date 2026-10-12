//
//  ClipNamingView.swift
//
//  Clipy
//
//  Overlay in the search panel for giving a clip a name and an optional expiry,
//  so it can be fetched later by name, e.g. with `clipy get <name>`.
//

import SwiftUI
import RealmSwift

// MARK: - Naming Actions
extension ClipSearchViewModel {
    func beginNaming() {
        guard let clip = selectedClip() else { return }
        namingClip = clip
    }

    func cancelNaming() {
        namingClip = nil
    }

    /// Saves the name and expiry, keeping the clip selected; a blank name clears both.
    func saveName(_ name: String, expiresAt: Date?) {
        defer { namingClip = nil }
        guard let clip = namingClip else { return }
        guard let realm = Realm.safeInstance() else { return }
        guard let realmClip = realm.object(ofType: CPYClip.self, forPrimaryKey: clip.dataHash) else { return }
        AppEnvironment.current.clipService.setName(name, expiresAt: expiresAt, for: realmClip)
        loadClips()
        if let index = clips.firstIndex(where: { $0.dataHash == clip.dataHash }) {
            selectedIndex = index
            selectedIndices = [index]
        }
    }
}

// MARK: - Expiry Choice
enum ClipExpiryChoice: String, CaseIterable, Identifiable {
    case never = "Never"
    case oneHour = "1 hour"
    case oneDay = "24 hours"
    case oneWeek = "7 days"
    case custom = "Custom\u{2026}"

    var id: String { rawValue }

    /// The expiry date this choice means, counted from `now`. `custom` uses `customDate`.
    func expiresAt(now: Date = Date(), customDate: Date) -> Date? {
        switch self {
        case .never: return nil
        case .oneHour: return now.addingTimeInterval(60 * 60)
        case .oneDay: return now.addingTimeInterval(60 * 60 * 24)
        case .oneWeek: return now.addingTimeInterval(60 * 60 * 24 * 7)
        case .custom: return customDate
        }
    }
}

// MARK: - Naming View
struct ClipNamingView: View {
    let clip: ClipItemViewModel
    let onSave: (String, Date?) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var expiry: ClipExpiryChoice
    @State private var customDate: Date
    @FocusState private var isNameFocused: Bool

    init(clip: ClipItemViewModel, onSave: @escaping (String, Date?) -> Void, onCancel: @escaping () -> Void) {
        self.clip = clip
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: clip.name ?? "")
        // An existing expiry is shown as a custom date so it is kept unless changed
        _expiry = State(initialValue: clip.expiresAt == nil ? .never : .custom)
        _customDate = State(initialValue: clip.expiresAt ?? Date().addingTimeInterval(60 * 60))
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isCustomDateInPast: Bool {
        expiry == .custom && customDate <= Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.teal)
                Text(clip.name == nil ? "Name this clip" : "Rename clip")
                    .font(.system(size: 13, weight: .semibold))
            }

            Text(clip.displayTitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            TextField("e.g. github-token", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFocused)
                .onSubmit(save)

            Text("Fetch it later with: clipy get \(trimmedName.isEmpty ? "<name>" : trimmedName)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)

            Picker("Expires", selection: $expiry) {
                ForEach(ClipExpiryChoice.allCases) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            }
            .pickerStyle(.menu)

            if expiry == .custom {
                DatePicker("On", selection: $customDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
            }

            if expiry != .never {
                Text("The clip is deleted when it expires.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            HStack {
                if clip.name != nil {
                    Button("Remove Name", role: .destructive) {
                        onSave("", nil)
                    }
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty || isCustomDateInPast)
            }
        }
        .padding(18)
        .frame(width: 340)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(radius: 12)
        .onAppear {
            DispatchQueue.main.async { isNameFocused = true }
        }
        .onExitCommand(perform: onCancel)
    }

    private func save() {
        guard !trimmedName.isEmpty, !isCustomDateInPast else { return }
        onSave(trimmedName, expiry.expiresAt(customDate: customDate))
    }
}

// MARK: - Name Badge
/// Shows a clip's name, with its expiry as a tooltip, in the preview header.
struct ClipNameBadge: View {
    let name: String
    let expiryCaption: String?

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "tag.fill")
                .font(.system(size: 8))
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
            if let expiryCaption {
                Text("\u{00B7} \(expiryCaption)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(SwiftUI.Color.teal.opacity(0.15))
        .foregroundStyle(.teal)
        .clipShape(Capsule())
    }
}
