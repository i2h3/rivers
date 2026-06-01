// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation

///
/// Writer for activities which creates ``Message`` objects with transformed argument values.
///
protocol MessageDispatching {
    ///
    /// The message argument value transformer registry to use.
    ///
    var transformerRegistry: TransformerRegistry { get }

    ///
    /// Dispatch the given message for write out in the backend implementation.
    ///
    func dispatch(_ message: Message)
}

extension MessageDispatching {
    ///
    /// Shared implementation to translate a ``Writer`` call into a ``Message`` while also transforming the arguments with the help of ``TransformerRegistry``.
    ///
    func makeAndDispatchMessage(activity: ActivityID, parent: ActivityID?, date: Date, level: Level, label: StaticString, arguments: [String: Any?]) {
        var descriptiveArguments = [String: String?](minimumCapacity: arguments.count)

        for (key, value) in arguments {
            guard let value else {
                descriptiveArguments.updateValue(nil, forKey: key) // Unlike the subscript, this preserves the key for a missing value.
                continue
            }

            guard let transformed = transformerRegistry.transform(value) else {
                descriptiveArguments.updateValue(String(describing: value), forKey: key)
                continue
            }

            descriptiveArguments.updateValue(transformed, forKey: key)
        }

        dispatch(Message(activity: activity, parent: parent, date: date, level: level, label: "\(label)", arguments: descriptiveArguments))
    }
}
