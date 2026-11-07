import Foundation
import ApplicationServices
import AppKit

func attr(_ el: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    let err = AXUIElementCopyAttributeValue(el, name as CFString, &value)
    return err == .success ? value : nil
}

func str(_ el: AXUIElement, _ name: String) -> String {
    if let v = attr(el, name) as? String { return v }
    return ""
}

func point(_ el: AXUIElement, _ name: String) -> String {
    guard let v = attr(el, name) else { return "" }
    var p = CGPoint.zero
    if AXValueGetType(v as! AXValue) == .cgPoint, AXValueGetValue(v as! AXValue, .cgPoint, &p) {
        return "\(Int(p.x)),\(Int(p.y))"
    }
    var s = CGSize.zero
    if AXValueGetType(v as! AXValue) == .cgSize, AXValueGetValue(v as! AXValue, .cgSize, &s) {
        return "\(Int(s.width))x\(Int(s.height))"
    }
    return ""
}

func walk(_ el: AXUIElement, depth: Int, maxDepth: Int) {
    let pad = String(repeating: "  ", count: depth)
    let role = str(el, kAXRoleAttribute)
    let title = str(el, kAXTitleAttribute)
    let desc = str(el, kAXDescriptionAttribute)
    let help = str(el, kAXHelpAttribute)
    let value = (attr(el, kAXValueAttribute) as? String) ?? ""
    let pos = point(el, kAXPositionAttribute)
    let size = point(el, kAXSizeAttribute)
    var actions: CFArray?
    AXUIElementCopyActionNames(el, &actions)
    let actionList = (actions as? [String]) ?? []

    var line = "\(pad)\(role)"
    if !title.isEmpty { line += " title=\"\(title)\"" }
    if !desc.isEmpty { line += " desc=\"\(desc)\"" }
    if !help.isEmpty { line += " help=\"\(help)\"" }
    if !value.isEmpty { line += " value=\"\(value)\"" }
    if !pos.isEmpty { line += " pos=\(pos)" }
    if !size.isEmpty { line += " size=\(size)" }
    if !actionList.isEmpty { line += " actions=\(actionList)" }
    print(line)

    guard depth < maxDepth else { return }
    if let children = attr(el, kAXChildrenAttribute) as? [AXUIElement] {
        for child in children { walk(child, depth: depth + 1, maxDepth: maxDepth) }
    }
}

func find(_ el: AXUIElement, field: String, text: String, depth: Int = 0) -> AXUIElement? {
    let candidates: [String]
    switch field {
    case "help": candidates = [str(el, kAXHelpAttribute)]
    case "title": candidates = [str(el, kAXTitleAttribute)]
    case "desc": candidates = [str(el, kAXDescriptionAttribute)]
    case "value": candidates = [(attr(el, kAXValueAttribute) as? String) ?? ""]
    default: candidates = []
    }
    if candidates.contains(where: { $0.localizedCaseInsensitiveContains(text) }) {
        return el
    }
    guard depth < 30, let children = attr(el, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
    for child in children {
        if let hit = find(child, field: field, text: text, depth: depth + 1) { return hit }
    }
    return nil
}

func mouse(_ type: CGEventType, _ p: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
}

let args = CommandLine.arguments
let command = args.count >= 2 ? args[1] : ""
let isAction = command == "press" || command == "click" || command == "move" || command == "key" || command == "find" || command == "menu"
let pidIndex = isAction ? 2 : 1
guard args.count > pidIndex, let pid = pid_t(args[pidIndex]) else {
    print("usage: axdump <pid> [maxDepth] | axdump press <pid> <field> <text> | axdump click|move <pid> <x> <y>")
    exit(1)
}
let app = AXUIElementCreateApplication(pid)
NSRunningApplication(processIdentifier: pid)?.activate()

if command == "press" {
    guard args.count >= 5 else { print("usage: axpress <pid> <field> <text>"); exit(1) }
    guard let target = find(app, field: args[3], text: args[4]) else {
        print("not found: \(args[3])=\(args[4])")
        exit(2)
    }
    let err = AXUIElementPerformAction(target, kAXPressAction as CFString)
    print(err == .success ? "pressed" : "press failed: \(err.rawValue)")
    exit(err == .success ? 0 : 3)
}

if command == "menu" {
    guard args.count >= 5 else { print("usage: axdump menu <pid> <field> <text>"); exit(1) }
    guard let target = find(app, field: args[3], text: args[4]) else {
        print("not found: \(args[3])=\(args[4])")
        exit(2)
    }
    let err = AXUIElementPerformAction(target, kAXShowMenuAction as CFString)
    print(err == .success ? "menu shown" : "menu failed: \(err.rawValue)")
    exit(err == .success ? 0 : 3)
}

if command == "key" {
    guard args.count >= 4, let code = UInt16(args[3]) else {
        print("usage: axdump key <pid> <keycode>"); exit(1)
    }
    let src = CGEventSource(stateID: .hidSystemState)
    CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)?.post(tap: .cghidEventTap)
    usleep(40_000)
    CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)?.post(tap: .cghidEventTap)
    print("keyed")
    exit(0)
}

if command == "find" {
    guard args.count >= 5 else { print("usage: axdump find <pid> <field> <text>"); exit(1) }
    if let hit = find(app, field: args[3], text: args[4]) {
        print("role=\(str(hit, kAXRoleAttribute)) desc=\(str(hit, kAXDescriptionAttribute)) title=\(str(hit, kAXTitleAttribute)) value=\((attr(hit, kAXValueAttribute) as? String) ?? "") pos=\(point(hit, kAXPositionAttribute)) size=\(point(hit, kAXSizeAttribute))")
        exit(0)
    }
    print("not found")
    exit(2)
}

if command == "click" || command == "move" {
    guard args.count >= 5, let x = Double(args[3]), let y = Double(args[4]) else {
        print("usage: axclick <pid> <x> <y>"); exit(1)
    }
    let p = CGPoint(x: x, y: y)
    mouse(.mouseMoved, p)
    usleep(120_000)
    if command == "click" {
        mouse(.leftMouseDown, p)
        usleep(60_000)
        mouse(.leftMouseUp, p)
    }
    print("ok")
    exit(0)
}

let maxDepth = args.count >= 3 ? Int(args[2]) ?? 12 : 12
walk(app, depth: 0, maxDepth: maxDepth)
