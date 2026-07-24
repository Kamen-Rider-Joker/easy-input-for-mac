import Carbon

extension TISInputSource {
    var id: String? {
        getProperty(kTISPropertyInputSourceID) as? String
    }

    var localizedName: String? {
        getProperty(kTISPropertyLocalizedName) as? String
    }

    var category: String? {
        getProperty(kTISPropertyInputSourceCategory) as? String
    }

    var isEnabled: Bool {
        getProperty(kTISPropertyInputSourceIsEnabled) as? Bool ?? false
    }

    var isSelectCapable: Bool {
        getProperty(kTISPropertyInputSourceIsSelectCapable) as? Bool ?? false
    }

    private func getProperty(_ key: CFString) -> Any? {
        guard let raw = TISGetInputSourceProperty(self, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue()
    }
}
