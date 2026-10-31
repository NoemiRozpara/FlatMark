import Foundation

/// Resources shared by the SwiftPM fixture target and the demo app.
enum FlatMarkFixtureResources {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        // These sources compile into the bundle that embeds the raster.
        let owner = Bundle(for: BundleToken.self)
        return owner.url(forResource: "focaccia", withExtension: "jpeg") != nil ? owner : Bundle.main
        #endif
    }

    #if !SWIFT_PACKAGE
    private final class BundleToken {}
    #endif

    static var focacciaURL: URL? {
        bundle.url(forResource: "focaccia", withExtension: "jpeg")
    }
}
