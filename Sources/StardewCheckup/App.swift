import SwiftUI

@main
struct StardewCheckupApp: App {
    @StateObject private var model = AppModel()

    init() {
        // Headless mode: `StardewCheckup --dump <save file>` prints the report as text.
        let args = CommandLine.arguments
        Checkup.timingEnabled = args.contains("--timing")
        if let i = args.firstIndex(of: "--dump"), i + 1 < args.count {
            let url = URL(fileURLWithPath: args[i + 1])
            do {
                let report = try SaveLoader.load(url: url)
                print(PlainTextRenderer.render(report))
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
    }

    var body: some Scene {
        WindowGroup("Checkup for Stardew Valley") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(CommandLine.arguments.contains("--dark") ? .dark : (CommandLine.arguments.contains("--light") ? .light : nil))
        }
        .defaultSize(width: 1280, height: 860)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Save File…") { model.presentOpenPanel() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Reload") { model.reload() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(model.report == nil)
            }
            CommandGroup(replacing: .help) {
                Button("Acknowledgements") { model.showAcknowledgements = true }
                Link("Stardew Checkup web app", destination: URL(string: "https://mouseypounds.github.io/stardew-checkup/")!)
                Link("Stardew Valley Wiki", destination: URL(string: "https://stardewvalleywiki.com/")!)
            }
            CommandGroup(after: .pasteboard) {
                Button("Copy Report as Text") { model.copyAsText() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(model.report == nil)
            }
        }
        Settings {
            SettingsView().environmentObject(model)
        }
    }
}
