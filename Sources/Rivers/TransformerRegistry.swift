// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation

///
/// Container for managing closures which transform an argument value of an arbitrary type into a human-readable description string for the logging backends.
///
/// Often the description or debug description are not what developers want to have or change in their code or logs for different reasons.
/// This facility enables custom description output for values and types based on their type.
///
/// The package itself does not ship transformers for the many of platform type available to keep imports clean and not create unnecessary dependencies and incompatibilities.
///
/// You can register a closure to transform a complex object into a simple and custom description like this:
///
/// ```swift
/// register { (value: MyCustomType) in
///     "\(value.color) thing"
/// }
/// ```
///
public final class TransformerRegistry: @unchecked Sendable {
    private var transformers: [ObjectIdentifier: (Any) -> String?] = [:]

    ///
    /// Initialize a new object with default transformers for Foundation types.
    ///
    public init() {
        register { (url: URL) in
            url.absoluteString
        }
    }

    ///
    /// Register a new closure to transform the given value into a description.
    ///
    /// - Parameters:
    ///     - transformer: A closure which takes a single value and returns a description of it.
    ///
    public nonisolated func register<T>(_ transformer: @escaping (T) -> String) {
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
    func transform(_ value: Any) -> String? {
        let objectIdentifier = ObjectIdentifier(type(of: value))

        guard let closure = transformers[objectIdentifier] else {
            return nil
        }

        return closure(value)
    }
}
