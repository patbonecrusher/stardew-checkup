import SwiftUI

struct AcknowledgementsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acknowledgements").font(.title2.bold()).fontDesign(.rounded)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Group {
                        Text("Stardew Checkup (web app)").font(.headline)
                        Text("The achievement and completion logic in this app is a port of Stardew Checkup by MouseyPounds, released under the MIT License.")
                        Link("https://github.com/MouseyPounds/stardew-checkup", destination: URL(string: "https://github.com/MouseyPounds/stardew-checkup")!)
                        Text(Self.mit).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    Group {
                        Text("Stardew Valley Wiki").font(.headline)
                        Text("Game reference data in the XP, fish, item and character guides (prices, difficulties, experience values, locations, sources, schedules, gift tastes and heart-event conditions) was compiled from the Stardew Valley Wiki, whose content is available under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 license.")
                        Link("https://stardewvalleywiki.com/", destination: URL(string: "https://stardewvalleywiki.com/")!)
                    }
                    Group {
                        Text("Stardew Valley").font(.headline)
                        Text("Stardew Valley is developed by ConcernedApe. This app is an independent fan-made tool and is not affiliated with or endorsed by ConcernedApe.")
                    }
                }
                .textSelection(.enabled)
            }
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }
        }
        .padding(20)
        .frame(width: 560, height: 480)
    }

    static let mit = """
    MIT License

    Copyright (c) 2017 MouseyPounds

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    """
}
