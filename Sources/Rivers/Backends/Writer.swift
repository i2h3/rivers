// SPDX-FileCopyrightText: 2026 Iva Horn
// SPDX-License-Identifier: MIT

import Foundation

///
/// A convenience type alias to declare the long method signature in a single place.
///
typealias Writer = @Sendable (_ activity: ActivityID, _ parent: ActivityID?, _ date: Date, _ level: Level, _ label: String, _ arguments: [String: Any?]) -> Void
