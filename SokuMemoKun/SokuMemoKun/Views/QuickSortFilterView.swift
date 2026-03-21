import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.sokumemokun.app", category: "QuickSort")

// 爆速振り分けモード: 事前フィルタ選択シート
struct QuickSortFilterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Memo.createdAt, order: .reverse) private var allMemos: [Memo]
    @Query(sort: \Tag.sortOrder) private var allTags: [Tag]

    // フィルタ条件（複数選択可）
    @State private var filterNoTag = false
    @State private var filterNoTitle = false
    @State private var filterOld = false
    @State private var filterAll = false
    @State private var filterByTag = false
    @State private var selectedTagIDs: Set<UUID> = []

    var onStart: ([Memo]) -> Void
    var onCancel: (() -> Void)? = nil

    // 3ヶ月前の基準日
    private var threeMonthsAgo: Date {
        Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    }

    // 親タグ一覧
    private var parentTags: [Tag] {
        allTags.filter { $0.parentTagID == nil }
    }

    private var filteredCount: Int { filteredMemos.count }

    private var filteredMemos: [Memo] {
        if filterAll { return allMemos }
        var result: Set<UUID> = []
        for memo in allMemos {
            if filterNoTag && memo.tags.isEmpty {
                result.insert(memo.id)
            }
            if filterNoTitle && memo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.insert(memo.id)
            }
            if filterOld {
                let lastAccess = memo.lastViewedAt ?? memo.updatedAt
                if lastAccess < threeMonthsAgo {
                    result.insert(memo.id)
                }
            }
            if filterByTag && !selectedTagIDs.isEmpty {
                // メモが選択されたタグのいずれかを持っていればOK
                let memoTagIDs = Set(memo.tags.map { $0.id })
                if !memoTagIDs.isDisjoint(with: selectedTagIDs) {
                    result.insert(memo.id)
                }
            }
        }
        return allMemos.filter { result.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // ヘッダー
                    VStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.orange)
                        Text("爆速振り分けモード")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("対象のメモを選んでください")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                    // フィルタ条件
                    VStack(spacing: 0) {
                        filterRow(
                            icon: "tag.slash", iconColor: .orange,
                            title: "タグなしのメモ",
                            count: allMemos.filter { $0.tags.isEmpty }.count,
                            isOn: $filterNoTag
                        )
                        Divider().padding(.leading, 54)

                        filterRow(
                            icon: "text.badge.minus", iconColor: .blue,
                            title: "タイトルなしのメモ",
                            count: allMemos.filter { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count,
                            isOn: $filterNoTitle
                        )
                        Divider().padding(.leading, 54)

                        filterRow(
                            icon: "clock.badge.exclamationmark", iconColor: .purple,
                            title: "3ヶ月以上開いていない",
                            count: allMemos.filter { ($0.lastViewedAt ?? $0.updatedAt) < threeMonthsAgo }.count,
                            isOn: $filterOld
                        )
                        Divider().padding(.leading, 54)

                        // 特定のタグ
                        filterRow(
                            icon: "tag.fill", iconColor: .green,
                            title: "特定のタグのメモ",
                            count: filterByTag && !selectedTagIDs.isEmpty
                                ? allMemos.filter { memo in !Set(memo.tags.map { $0.id }).isDisjoint(with: selectedTagIDs) }.count
                                : 0,
                            isOn: $filterByTag
                        )

                        // タグ選択リスト（filterByTagがONの時だけ展開）
                        if filterByTag {
                            VStack(spacing: 0) {
                                ForEach(parentTags, id: \.id) { tag in
                                    let isSelected = selectedTagIDs.contains(tag.id)
                                    let memoCount = allMemos.filter { memo in memo.tags.contains(where: { $0.id == tag.id }) }.count

                                    Button {
                                        if isSelected {
                                            selectedTagIDs.remove(tag.id)
                                        } else {
                                            selectedTagIDs.insert(tag.id)
                                        }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Circle()
                                                .fill(tagColor(for: tag.colorIndex))
                                                .frame(width: 12, height: 12)

                                            Text(tag.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.primary)

                                            Spacer()

                                            Text("\(memoCount)件")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)

                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 18))
                                                .foregroundStyle(isSelected ? .green : .secondary.opacity(0.3))
                                        }
                                        .contentShape(Rectangle())
                                        .padding(.horizontal, 20)
                                        .padding(.leading, 34)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)

                                    if tag.id != parentTags.last?.id {
                                        Divider().padding(.leading, 74)
                                    }
                                }
                            }
                            .background(Color(uiColor: .tertiarySystemBackground))
                        }

                        Divider().padding(.leading, 54)

                        filterRow(
                            icon: "tray.full.fill", iconColor: .gray,
                            title: "すべてのメモ",
                            count: allMemos.count,
                            isOn: $filterAll
                        )
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }
            }

            // 開始ボタン（固定フッター）
            VStack {
                Button {
                    onStart(filteredMemos)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("開始（\(filteredCount)件）")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(filteredCount > 0 ? Color.orange : Color.gray)
                    )
                }
                .disabled(filteredCount == 0)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { onCancel?() ?? dismiss() }
                }
            }
        }
        // 排他制御
        .onChange(of: filterAll) { _, newVal in
            if newVal {
                filterNoTag = false
                filterNoTitle = false
                filterOld = false
                filterByTag = false
                selectedTagIDs.removeAll()
            }
        }
        .onChange(of: filterNoTag) { _, newVal in if newVal { filterAll = false } }
        .onChange(of: filterNoTitle) { _, newVal in if newVal { filterAll = false } }
        .onChange(of: filterOld) { _, newVal in if newVal { filterAll = false } }
        .onChange(of: filterByTag) { _, newVal in
            if newVal { filterAll = false }
            if !newVal { selectedTagIDs.removeAll() }
        }
    }

    @ViewBuilder
    private func filterRow(icon: String, iconColor: Color, title: String, count: Int, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
                    .frame(width: 30)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(count)件")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn.wrappedValue ? .orange : .secondary.opacity(0.4))
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}
