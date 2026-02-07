import Combine
import Foundation
import SwiftData

/// Repository for Habit CRUD operations
@MainActor
public final class HabitRepository: ObservableObject {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create

    /// Creates a new habit
    @discardableResult
    public func create(
        name: String,
        icon: String = "circle.fill",
        colorHex: String = "#007AFF",
        trackingStyle: TrackingStyle = .occurrence,
        tags: [String] = [],
        isLocalOnly: Bool = false
    ) throws -> Habit {
        let maxOrder = try fetchAll().map(\.displayOrder).max() ?? -1

        let habit = Habit(
            name: name,
            icon: icon,
            colorHex: colorHex,
            trackingStyle: trackingStyle,
            tags: tags,
            isLocalOnly: isLocalOnly,
            displayOrder: maxOrder + 1
        )

        modelContext.insert(habit)
        try modelContext.save()
        return habit
    }

    // MARK: - Read

    /// Fetches all active (non-archived) habits ordered by displayOrder
    public func fetchAll() throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.displayOrder)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches all habits including archived
    public func fetchAllIncludingArchived() throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.displayOrder)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches archived habits only
    public func fetchArchived() throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.isArchived },
            sortBy: [SortDescriptor(\.displayOrder)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches a habit by ID
    public func fetch(byId id: UUID) throws -> Habit? {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Fetches habits with specific tags
    public func fetch(withTag tag: String) throws -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.tags.contains(tag) && !$0.isArchived },
            sortBy: [SortDescriptor(\.displayOrder)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Update

    /// Updates a habit's basic properties
    public func update(
        _ habit: Habit,
        name: String? = nil,
        icon: String? = nil,
        colorHex: String? = nil,
        trackingStyle: TrackingStyle? = nil,
        tags: [String]? = nil,
        isLocalOnly: Bool? = nil
    ) throws {
        if let name = name { habit.name = name }
        if let icon = icon { habit.icon = icon }
        if let colorHex = colorHex { habit.colorHex = colorHex }
        if let trackingStyle = trackingStyle { habit.trackingStyle = trackingStyle }
        if let tags = tags { habit.tags = tags }
        if let isLocalOnly = isLocalOnly { habit.isLocalOnly = isLocalOnly }

        habit.updatedAt = Date()
        try modelContext.save()
    }

    /// Archives a habit (soft delete)
    public func archive(_ habit: Habit) throws {
        habit.isArchived = true
        habit.updatedAt = Date()
        try modelContext.save()
    }

    /// Unarchives a habit
    public func unarchive(_ habit: Habit) throws {
        habit.isArchived = false
        habit.updatedAt = Date()
        try modelContext.save()
    }

    /// Updates the display order of habits
    public func updateOrder(_ habits: [Habit]) throws {
        for (index, habit) in habits.enumerated() {
            habit.displayOrder = index
            habit.updatedAt = Date()
        }
        try modelContext.save()
    }

    // MARK: - Delete

    /// Permanently deletes a habit and all its entries
    public func delete(_ habit: Habit) throws {
        modelContext.delete(habit)
        try modelContext.save()
    }

    /// Permanently deletes all archived habits
    public func deleteAllArchived() throws {
        let archived = try fetchArchived()
        for habit in archived {
            modelContext.delete(habit)
        }
        try modelContext.save()
    }
}
