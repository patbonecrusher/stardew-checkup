import Foundation

// MARK: - Lightweight DOM

/// Minimal element tree built with the streaming `XMLParser`. Foundation's
/// `XMLDocument`/XPath has a large fixed cost per query, which dominated when a
/// save needed thousands of small lookups, so we keep our own tree instead.
final class XElement {
    let name: String
    let attributes: [String: String]
    fileprivate(set) var ownText: String = ""
    fileprivate(set) var children: [XElement] = []
    weak var parent: XElement?

    init(name: String, attributes: [String: String], parent: XElement?) {
        self.name = name
        self.attributes = attributes
        self.parent = parent
    }

    /// Concatenated text content of this element and its descendants (DOM `textContent`).
    var text: String {
        if children.isEmpty { return ownText }
        var out = ownText
        for c in children { out += c.text }
        return out
    }
}

/// The parsed document plus indexes used to answer root-level queries quickly.
final class XTree {
    let root: XElement
    /// Every element in document order, keyed by element name.
    private(set) var byName: [String: [XElement]] = [:]
    /// Every element that carries a namespaced `type` attribute (e.g. `xsi:type`), keyed by its value.
    private(set) var byType: [String: [XElement]] = [:]

    init(root: XElement) {
        self.root = root
        index(root)
    }

    private func index(_ el: XElement) {
        byName[el.name, default: []].append(el)
        for (k, v) in el.attributes where k.hasSuffix(":type") {
            byType[v, default: []].append(el)
        }
        for c in el.children { index(c) }
    }

    /// Parses XML data into a tree. Throws on malformed XML or an empty document.
    static func parse(_ data: Data) throws -> XTree {
        let builder = TreeBuilder()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        parser.delegate = builder
        let ok = parser.parse()
        if let err = builder.error ?? (ok ? nil : parser.parserError) {
            throw err
        }
        guard let root = builder.root else {
            throw NSError(domain: "StardewCheckup", code: 1, userInfo: [NSLocalizedDescriptionKey: "The document is empty."])
        }
        return XTree(root: root)
    }
}

private final class TreeBuilder: NSObject, XMLParserDelegate {
    var root: XElement?
    var error: Error?
    private var stack: [XElement] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let el = XElement(name: elementName, attributes: attributes, parent: stack.last)
        if let top = stack.last { top.children.append(el) } else { root = el }
        stack.append(el)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        _ = stack.popLast()
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.ownText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        stack.last?.ownText += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        if error == nil { error = parseError }
    }
}

// MARK: - jQuery-flavoured wrapper

/// Thin wrapper so the port of stardew-checkup.js can keep its selector-style traversal.
/// `find("a > b c")` means: descendants named `a`, their children `b`, their descendants `c`.
struct XNode {
    let element: XElement
    /// Present only on the document root; enables indexed lookups.
    let tree: XTree?

    init(_ element: XElement, tree: XTree? = nil) {
        self.element = element
        self.tree = tree
    }

    var name: String { element.name }

    /// Text content (jQuery `.text()` on a single element).
    var text: String { element.text }

    var parent: XNode? { element.parent.map { XNode($0) } }

    func attr(_ name: String) -> String? { element.attributes[name] }

    /// Direct children with the given element name (jQuery `.children(name)`).
    func children(_ name: String) -> [XNode] {
        element.children.filter { $0.name == name }.map { XNode($0) }
    }

    /// All direct element children.
    var allChildren: [XNode] { element.children.map { XNode($0) } }

    func child(_ name: String) -> XNode? {
        element.children.first { $0.name == name }.map { XNode($0) }
    }

    /// Text of the first direct child with this name, or "".
    func childText(_ name: String) -> String { child(name)?.text ?? "" }

    /// jQuery `.find(selector)`; supports `>` (child) and whitespace (descendant)
    /// combinators plus `*`, `[@attr='value']` and `[.='text']` filters.
    func find(_ selector: String) -> [XNode] {
        var steps = XNode.steps(fromSelector: selector)
        guard !steps.isEmpty else { return [] }
        var current: [XElement]
        if let tree = tree {
            // Root query: resolve the first (descendant) step through the indexes.
            let first = steps.removeFirst()
            if first.name != "*" {
                current = tree.byName[first.name] ?? []
            } else if let (a, v) = first.attr, a.hasSuffix(":type") {
                current = tree.byType[v] ?? []
            } else {
                current = []
                XNode.collectDescendants(element, Step(name: "*", attr: nil, textEquals: nil, descendant: true), into: &current)
            }
            // `descendant-or-self`: a leading "SaveGame" must also match the root itself.
            if XNode.matches(element, first) { current.insert(element, at: 0) }
            current = current.filter { XNode.matches($0, first) }
        } else {
            current = [element]
        }
        return XNode.walk(from: current, steps: steps).map { XNode($0) }
    }

    func first(_ selector: String) -> XNode? { find(selector).first }

    /// Text of the first match of the selector, or "".
    func text(_ selector: String) -> String { first(selector)?.text ?? "" }

    /// Climb ancestors until an element with the given name is found.
    func ancestor(named name: String) -> XNode? {
        var cur = element.parent
        while let c = cur {
            if c.name == name { return XNode(c) }
            cur = c.parent
        }
        return nil
    }

    // MARK: Selector engine

    struct Step {
        var name: String          // "*" matches any element
        var attr: (String, String)?
        var textEquals: String?
        var descendant: Bool
    }

    static func steps(fromSelector selector: String) -> [Step] {
        let tokens = selector.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        var steps: [Step] = []
        var pendingChild = false
        var isFirst = true
        for tok in tokens {
            if tok == ">" { pendingChild = true; continue }
            var name = tok
            var attr: (String, String)? = nil
            var textEq: String? = nil
            if let open = tok.firstIndex(of: "["), let close = tok.lastIndex(of: "]") {
                name = String(tok[..<open])
                let filter = String(tok[tok.index(after: open)..<close])
                if let eq = filter.range(of: "='") {
                    let lhs = String(filter[..<eq.lowerBound])
                    var rhs = String(filter[eq.upperBound...])
                    if rhs.hasSuffix("'") { rhs.removeLast() }
                    if lhs == "." { textEq = rhs } else if lhs.hasPrefix("@") { attr = (String(lhs.dropFirst()), rhs) }
                }
            }
            if name.isEmpty { name = "*" }
            steps.append(Step(name: name, attr: attr, textEquals: textEq, descendant: isFirst || !pendingChild))
            pendingChild = false
            isFirst = false
        }
        return steps
    }

    fileprivate static func matches(_ el: XElement, _ step: Step) -> Bool {
        if step.name != "*" && el.name != step.name { return false }
        if let (a, v) = step.attr, el.attributes[a] != v { return false }
        if let t = step.textEquals, el.text != t { return false }
        return true
    }

    fileprivate static func collectDescendants(_ el: XElement, _ step: Step, into out: inout [XElement]) {
        for child in el.children {
            if matches(child, step) { out.append(child) }
            collectDescendants(child, step, into: &out)
        }
    }

    static func walk(from start: [XElement], steps: [Step]) -> [XElement] {
        var current = start
        for step in steps {
            var next: [XElement] = []
            for el in current {
                if step.descendant {
                    collectDescendants(el, step, into: &next)
                } else {
                    for child in el.children where matches(child, step) { next.append(child) }
                }
            }
            if step.descendant && current.count > 1 {
                var seen = Set<ObjectIdentifier>()
                next = next.filter { seen.insert(ObjectIdentifier($0)).inserted }
            }
            current = next
        }
        return current
    }
}

// MARK: - JS-style helpers

/// JavaScript `Number(x)`-ish conversion. Empty or non-numeric strings become 0.
func num(_ s: String?) -> Int {
    guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return 0 }
    if let i = Int(s) { return i }
    if let d = Double(s) { return Int(d) }
    return 0
}

func dbl(_ s: String?) -> Double {
    guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return 0 }
    return Double(s) ?? 0
}

/// semver-compare port (James Halliday). Returns -1, 0 or 1.
func compareSemVer(_ a: String, _ b: String) -> Int {
    let pa = a.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    let pb = b.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    for i in 0..<3 {
        let na = i < pa.count ? Double(pa[i]) : nil
        let nb = i < pb.count ? Double(pb[i]) : nil
        switch (na, nb) {
        case let (x?, y?):
            if x > y { return 1 }
            if y > x { return -1 }
        case (.some, .none):
            return 1
        case (.none, .some):
            return -1
        case (.none, .none):
            continue
        }
    }
    return 0
}

func addCommas(_ x: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.groupingSeparator = ","
    f.usesGroupingSeparator = true
    return f.string(from: NSNumber(value: x)) ?? String(x)
}

func capitalize(_ s: String) -> String {
    guard let first = s.first else { return s }
    return first.uppercased() + s.dropFirst()
}

/// Formats a JS-style number: integers without decimals, otherwise shortest form.
func jsNum(_ d: Double) -> String {
    if d == d.rounded() && abs(d) < 1e15 { return String(Int(d)) }
    var s = String(format: "%.6f", d)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}

/// JS `Number.toFixed(places)`.
func toFixed(_ d: Double, _ places: Int) -> String {
    String(format: "%.\(places)f", d)
}
