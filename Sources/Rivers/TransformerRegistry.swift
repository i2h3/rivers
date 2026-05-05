import Foundation

///
/// Container for managing closures which transform a value of an arbitrary type into a human-readable description string for the backends.
///
public final class TransformerRegistry: @unchecked Sendable {
    private var transformers: [ObjectIdentifier: (Any) -> String?] = [:]

    ///
    /// Registers default transformers for Foundation types.
    ///
    public init() {
        register { (url: URL) in
            url.absoluteString
        }
    }

    ///
    /// Register a new closure to transform the given value into a description.
    ///
    public nonisolated func register<T>(_ transformer: @escaping (T) -> String?) {
        let objectIdentifier = ObjectIdentifier(T.self)

        transformers[objectIdentifier] = {
            guard let casted = $0 as? T else {
                return nil
            }

            return transformer(casted)
        }
    }

    ///
    /// Try to transform the given value to a descriptive string.
    ///
    /// - Returns: `nil`, if no type matching transformer was found.
    ///
    public func transform(_ value: Any) -> String? {
        let objectIdentifier = ObjectIdentifier(type(of: value))

        guard let closure = transformers[objectIdentifier] else {
            return nil
        }

        return closure(value)
    }
}
