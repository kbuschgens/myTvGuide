import Foundation
import ObjectiveC

/// Testmodus: privé-API `LSApplicationWorkspace` om URL-schema's en bundle-ID's op het toestel op te zoeken
/// en een app op bundle-ID te openen. Werkt alleen voor eigen (Xcode-)installaties; nooit naar de App Store sturen.
/// Elke aanroep wordt eerst met `responds(to:)` gecontroleerd, zodat een ontbrekende methode niets laat crashen.
@MainActor
enum PrivateLauncher {
    struct Report {
        var lines: [String] = []
        var schemes: [String] = []
        var bundleIDs: [String] = []
    }

    private static var workspace: NSObject? {
        guard let cls = objc_getClass("LSApplicationWorkspace") as? NSObject else { return nil }
        return call(cls, "defaultWorkspace") as? NSObject
    }

    private static func call(_ object: NSObject, _ name: String) -> AnyObject? {
        let sel = NSSelectorFromString(name)
        guard object.responds(to: sel) else { return nil }
        return object.perform(sel)?.takeUnretainedValue()
    }

    /// Alle geregistreerde schema's en apps waarvan naam, bundle-ID of scheme `term` bevat.
    static func search(_ term: String) -> Report {
        var report = Report()
        guard let ws = workspace else {
            report.lines.append("LSApplicationWorkspace niet beschikbaar op dit toestel.")
            return report
        }

        for name in ["publicURLSchemes", "privateURLSchemes"] {
            guard let all = call(ws, name) as? [String] else {
                report.lines.append("\(name): niet beschikbaar")
                continue
            }
            let hits = all.filter { $0.localizedCaseInsensitiveContains(term) }
            report.lines.append("\(name) (\(all.count) totaal): \(hits.isEmpty ? "geen treffers" : hits.joined(separator: ", "))")
            report.schemes += hits
        }

        let apps = (call(ws, "allInstalledApplications") ?? call(ws, "allApplications")) as? [NSObject]
        guard let apps else {
            report.lines.append("Lijst met apps: niet beschikbaar")
            return report
        }
        report.lines.append("Apps zichtbaar: \(apps.count)")
        for app in apps {
            let id = call(app, "bundleIdentifier") as? String ?? ""
            let name = call(app, "localizedName") as? String ?? ""
            guard (id + " " + name).localizedCaseInsensitiveContains(term) else { continue }
            report.bundleIDs.append(id)
            var line = "App: \(name) (\(id))"
            if let schemes = urlSchemes(of: app), !schemes.isEmpty {
                line += " schema's: " + schemes.joined(separator: ", ")
                report.schemes += schemes
            }
            report.lines.append(line)
        }
        report.schemes = Array(Set(report.schemes)).sorted()
        return report
    }

    /// Schema's uit de Info.plist van een andere app; lukt alleen als de sandbox dat toelaat.
    private static func urlSchemes(of app: NSObject) -> [String]? {
        if let claimed = call(app, "claimedURLSchemes") as? [String] { return claimed }
        guard let url = call(app, "bundleURL") as? URL,
              let info = NSDictionary(contentsOf: url.appendingPathComponent("Info.plist")),
              let types = info["CFBundleURLTypes"] as? [[String: Any]] else { return nil }
        return types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    }

    /// Opent een app op bundle-ID (zonder deep link naar een zender).
    static func open(bundleID: String) -> Bool {
        guard let ws = workspace else { return false }
        let sel = NSSelectorFromString("openApplicationWithBundleID:")
        guard ws.responds(to: sel), let imp = ws.method(for: sel) else { return false }
        typealias Fn = @convention(c) (AnyObject, Selector, NSString) -> Bool
        return unsafeBitCast(imp, to: Fn.self)(ws, sel, bundleID as NSString)
    }
}
