//
//  XMLNode.swift
//  AdSDK
//
//  A tiny read-only DOM. `XMLParser`'s streaming delegate is awkward for deeply
//  nested documents like VAST/VMAP, so we first build a simple element tree and
//  then let the VAST/VMAP parsers walk it declaratively. Element lookups match on
//  the *local* name (ignoring any `vmap:`/`xmlns` prefix) so the same code reads
//  both namespaced (VMAP) and plain (VAST) markup.
//

import Foundation

/// One element node in the parsed tree.
final class XMLNode {
    let name: String
    private(set) var attributes: [String: String]
    private(set) var children: [XMLNode] = []
    weak var parent: XMLNode?

    /// Raw accumulated character + CDATA content for this element.
    fileprivate var rawText: String = ""

    init(name: String, attributes: [String: String] = [:]) {
        self.name = name
        self.attributes = attributes
    }

    /// Element content with surrounding whitespace/newlines trimmed.
    var text: String { rawText.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The local name with any namespace prefix removed (`vmap:AdBreak` -> `AdBreak`).
    var localName: String { Self.localName(name) }

    static func localName(_ qualified: String) -> String {
        guard let colon = qualified.firstIndex(of: ":") else { return qualified }
        return String(qualified[qualified.index(after: colon)...])
    }

    /// First descendant-or-self direct child whose local name matches.
    func firstChild(_ localName: String) -> XMLNode? {
        children.first { $0.localName == localName }
    }

    /// All direct children whose local name matches.
    func children(named localName: String) -> [XMLNode] {
        children.filter { $0.localName == localName }
    }

    /// Recursively collects all descendants whose local name matches.
    func descendants(named localName: String) -> [XMLNode] {
        var result: [XMLNode] = []
        for child in children {
            if child.localName == localName { result.append(child) }
            result.append(contentsOf: child.descendants(named: localName))
        }
        return result
    }

    /// Convenience: trimmed text of the first matching child.
    func childText(_ localName: String) -> String? {
        firstChild(localName)?.text
    }

    /// Attribute lookup tolerant of a namespace prefix on the attribute name.
    func attribute(_ name: String) -> String? {
        if let exact = attributes[name] { return exact }
        return attributes.first { Self.localName($0.key) == name }?.value
    }

    fileprivate func appendText(_ string: String) { rawText += string }
    fileprivate func add(_ child: XMLNode) {
        child.parent = self
        children.append(child)
    }
}

/// Builds an ``XMLNode`` tree from raw XML data. Returns `nil` on malformed XML.
enum XMLTreeBuilder {
    static func build(from data: Data) -> XMLNode? {
        let parser = XMLParser(data: data)
        let delegate = Delegate()
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        guard parser.parse(), let root = delegate.root else { return nil }
        return root
    }

    static func build(from string: String) -> XMLNode? {
        guard let data = string.data(using: .utf8) else { return nil }
        return build(from: data)
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        private(set) var root: XMLNode?
        private var stack: [XMLNode] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String: String]) {
            let node = XMLNode(name: elementName, attributes: attributeDict)
            if let parent = stack.last {
                parent.add(node)
            } else {
                root = node
            }
            stack.append(node)
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            stack.last?.appendText(string)
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            guard let text = String(data: CDATABlock, encoding: .utf8) else { return }
            stack.last?.appendText(text)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            if !stack.isEmpty { stack.removeLast() }
        }
    }
}
