import Foundation

extension KeyedDecodingContainer {
    /// Reads a value, falling back to `fallback` when the key is absent *or*
    /// holds something unreadable (an enum case that no longer exists, say).
    ///
    /// Swift's synthesised `Codable` requires every key to be present even when
    /// the property has a default, so adding a new setting would otherwise make
    /// every previously saved settings file fail to decode — silently resetting
    /// the user's widgets. Every config type here decodes through this instead.
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}
