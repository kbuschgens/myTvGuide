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

    private static func call(_ object: NSObject, _ name: String, _ argument: Any? = nil) -> AnyObject? {
        let sel = NSSelectorFromString(name)
        guard object.responds(to: sel) else { return nil }
        if let argument { return object.perform(sel, with: argument)?.takeUnretainedValue() }
        return object.perform(sel)?.takeUnretainedValue()
    }

    private static func strings(_ value: AnyObject?) -> [String]? {
        if let set = value as? Set<String> { return set.sorted() }
        return value as? [String]
    }

    private static func proxy(for bundleID: String) -> NSObject? {
        guard let cls = objc_getClass("LSApplicationProxy") as? NSObject else { return nil }
        return call(cls, "applicationProxyForIdentifier:", bundleID) as? NSObject
    }

    /// Methodenamen van een object (en superklassen) die een van de termen bevatten.
    private static func methodNames(of object: NSObject, containing terms: [String]) -> [String] {
        var names = Set<String>()
        var cls: AnyClass? = type(of: object)
        while let current = cls, ObjectIdentifier(current) != ObjectIdentifier(NSObject.self) {
            var count: UInt32 = 0
            if let list = class_copyMethodList(current, &count) {
                for i in 0..<Int(count) {
                    let name = NSStringFromSelector(method_getName(list[i]))
                    if terms.contains(where: { name.localizedCaseInsensitiveContains($0) }) { names.insert(name) }
                }
                free(list)
            }
            cls = class_getSuperclass(current)
        }
        return names.sorted()
    }

    /// Alles wat over één app op te vragen is: naam, URL-schema's en beschikbare methodes.
    static func inspect(bundleID: String) -> Report {
        var report = Report()
        guard let app = proxy(for: bundleID) else {
            report.lines.append("LSApplicationProxy niet beschikbaar voor \(bundleID)")
            return report
        }
        report.bundleIDs = [bundleID]
        report.lines.append("Naam: \(call(app, "localizedName") as? String ?? "?")")
        if let schemes = urlSchemes(of: app) {
            report.lines.append("Schema's: \(schemes.isEmpty ? "geen" : schemes.joined(separator: ", "))")
            report.schemes = schemes
        } else {
            report.lines.append("Schema's: niet opvraagbaar")
        }
        if let url = call(app, "bundleURL") as? URL { report.lines.append("Bundle: \(url.path)") }
        let methods = methodNames(of: app, containing: ["scheme", "url", "activity", "info"])
        report.lines.append("Methodes (\(methods.count)): " + methods.prefix(40).joined(separator: " "))
        return report
    }

    /// Geeft een web-URL als universal link (NSUserActivity) rechtstreeks aan de app, zonder AASA-controle.
    static func openUserActivity(_ url: URL, bundleID: String) -> String {
        guard let ws = workspace, let app = proxy(for: bundleID) else { return "workspace/proxy niet beschikbaar" }
        let activity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        activity.webpageURL = url
        typealias Completion = @convention(block) (Bool, NSError?) -> Void
        let completion: Completion = { _, _ in }
        let withOptions = NSSelectorFromString("openUserActivity:withApplicationProxy:options:completionHandler:")
        if ws.responds(to: withOptions), let imp = ws.method(for: withOptions) {
            typealias Fn = @convention(c) (AnyObject, Selector, NSUserActivity, AnyObject, NSDictionary?, Completion) -> Void
            unsafeBitCast(imp, to: Fn.self)(ws, withOptions, activity, app, nil, completion)
            return "openUserActivity (met options) aangeroepen voor \(url.absoluteString)"
        }
        let plain = NSSelectorFromString("openUserActivity:withApplicationProxy:completionHandler:")
        if ws.responds(to: plain), let imp = ws.method(for: plain) {
            typealias Fn = @convention(c) (AnyObject, Selector, NSUserActivity, AnyObject, Completion) -> Void
            unsafeBitCast(imp, to: Fn.self)(ws, plain, activity, app, completion)
            return "openUserActivity aangeroepen voor \(url.absoluteString)"
        }
        return "openUserActivity niet beschikbaar; methodes: " + methodNames(of: ws, containing: ["activity", "open"]).joined(separator: " ")
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
        if let claimed = strings(call(app, "claimedURLSchemes")) { return claimed }
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
