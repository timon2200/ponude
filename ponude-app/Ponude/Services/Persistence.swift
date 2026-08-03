import Foundation
import SwiftData
import os

/// Central save helper.
///
/// Every write in the app goes through here instead of `try? context.save()`.
/// A swallowed save error is indistinguishable from "the user never pressed the
/// button" — which is exactly how the app could look empty on every launch
/// without a single trace in the logs. Failures are logged to the unified log
/// (visible in Console.app, filter on subsystem `hr.lotusrc.ponude`) and to
/// stdout, so a silent data loss can never happen again.
enum Persistence {

    static let log = Logger(subsystem: "hr.lotusrc.ponude", category: "persistence")

    /// Saves the context and reports the outcome. Returns `true` on success.
    @discardableResult
    static func save(_ context: ModelContext, _ label: String) -> Bool {
        saveOrError(context, label) == nil
    }

    /// Saves the context. Returns `nil` on success, or a message suitable for
    /// showing to the user when the write did not go through.
    static func saveOrError(_ context: ModelContext, _ label: String) -> String? {
        guard context.hasChanges else { return nil }
        do {
            try context.save()
            log.debug("Saved: \(label, privacy: .public)")
            return nil
        } catch {
            log.error("SAVE FAILED (\(label, privacy: .public)): \(error.localizedDescription, privacy: .public)")
            print("[Ponude] ❌ SAVE FAILED (\(label)): \(error)")
            return error.localizedDescription
        }
    }
}
