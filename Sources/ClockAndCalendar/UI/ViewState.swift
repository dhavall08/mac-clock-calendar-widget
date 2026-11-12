import SwiftUI

/// The `State` property wrapper, reached by its type name.
///
/// In the macOS 27 SDK a bare `@State` resolves to a macro, and the macro
/// plugin ships only with Xcode. Going through a typealias picks the plain
/// property wrapper, so the app still builds with Command Line Tools alone.
/// Behaviour is identical.
typealias ViewState<Value> = SwiftUI.State<Value>
