// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

///
/// The significance of a log message or activity.
///
public enum Level: UInt, RawRepresentable, Codable, Sendable {
    ///
    /// Use this only for additional information required for development or in depth troubleshooting.
    ///
    case debug = 0

    ///
    /// Use this as the default for generic messages.
    ///
    case info = 1

    ///
    /// Use this for problems.
    ///
    case error = 2
}
