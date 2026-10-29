import Foundation

/// Resources shared by the SwiftPM fixture target and the demo app.
enum FlatMarkFixtureResources {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }

    static var focacciaURL: URL? {
        bundle.url(forResource: "focaccia", withExtension: "jpeg")
    }
}
