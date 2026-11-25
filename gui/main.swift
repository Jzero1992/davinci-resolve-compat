import AppKit

final class DropView: NSView {
    var onDrop: ((URL)->Void)?
    override init(frame: NSRect) { super.init(frame: frame); registerForDraggedTypes([.fileURL]) }
    required init?(coder: NSCoder) { fatalError() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: nil) ? .copy : []
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let url = urls.first else { return false }
        onDrop?(url); return true
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var source: URL?
    var result: URL?
    var targetMajor = 20
    var outputFolder: URL?
    let targetPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    let folderLabel = NSTextField(wrappingLabelWithString: "输出位置：默认保存在原工程旁边")
    let folderButton = NSButton(title: "更改位置…", target: nil, action: nil)
    var experimental = false
    var busy = false
    var pending: URL?
    let filename = NSTextField(labelWithString: "拖入 .dra 或 .drp 工程")
    let path = NSTextField(wrappingLabelWithString: "也可以点击下方按钮，选择本机或挂载磁盘中的工程。")
    let details = NSTextField(wrappingLabelWithString: "选择工程后，将检查保存版本与文件完整性。")
    let status = NSTextField(wrappingLabelWithString: "等待选择工程")
    let choose = NSButton(title: "选择工程…", target: nil, action: nil)
    let convertButton = NSButton(title: "生成兼容副本", target: nil, action: nil)
    let reveal = NSButton(title: "在访达中显示", target: nil, action: nil)
    let progress = NSProgressIndicator()

    func label(_ string: String, _ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSTextField {
        let v = NSTextField(wrappingLabelWithString: string); v.font = .systemFont(ofSize: size, weight: weight); return v
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu(); let item = NSMenuItem(); menu.addItem(item)
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "关于达芬奇工程兼容工具", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); item.submenu = appMenu
        let file = NSMenuItem(); menu.addItem(file); let fileMenu = NSMenu(title: "文件"); fileMenu.addItem(withTitle: "选择工程…", action: #selector(selectFile), keyEquivalent: "o"); file.submenu = fileMenu
        let edit = NSMenuItem(); menu.addItem(edit); let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c"); editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"); edit.submenu = editMenu
        NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 740,height: 735), styleMask: [.titled,.closable,.miniaturizable], backing: .buffered, defer: false)
        window.title = "达芬奇工程兼容工具"; window.appearance = NSAppearance(named: .darkAqua)
        let root = DropView(frame: NSRect(x: 0,y: 0,width: 740,height: 735)); root.onDrop = { [weak self] in self?.load($0) }; window.contentView = root
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 19; stack.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: root.leadingAnchor,constant: 32), stack.trailingAnchor.constraint(equalTo: root.trailingAnchor,constant: -32),stack.topAnchor.constraint(equalTo: root.topAnchor,constant: 28)])
        func add(_ view: NSView) { stack.addArrangedSubview(view); view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        let eyebrow = label("RESOLVE PROJECT COMPATIBILITY",11,.semibold); eyebrow.textColor = .secondaryLabelColor; add(eyebrow)
        add(label("让工程兼容旧版 Resolve",28,.semibold))
        let subtitle = label("21 → 20 / 20 → 19  ·  本地处理  ·  原工程保持不变",13); subtitle.textColor = .secondaryLabelColor; add(subtitle)
        let box = NSBox(); box.title = "源工程"; box.boxType = .custom; box.borderColor = .separatorColor; box.borderWidth = 1; box.cornerRadius = 10; box.contentViewMargins = NSSize(width: 20,height: 18)
        let inside = NSStackView(); inside.orientation = .vertical; inside.alignment = .leading; inside.spacing = 10; inside.translatesAutoresizingMaskIntoConstraints = false
        box.contentView!.addSubview(inside); NSLayoutConstraint.activate([inside.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor,constant: 18),inside.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor,constant: -18),inside.topAnchor.constraint(equalTo: box.contentView!.topAnchor,constant: 18),inside.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor,constant: -18)])
        filename.font = .systemFont(ofSize: 17,weight: .medium); filename.lineBreakMode = .byTruncatingMiddle
        path.font = .systemFont(ofSize: 12); path.textColor = .secondaryLabelColor; path.isSelectable = true; path.maximumNumberOfLines = 3
        choose.target = self; choose.action = #selector(selectFile); choose.bezelStyle = .rounded
        inside.addArrangedSubview(filename); inside.addArrangedSubview(path); inside.addArrangedSubview(choose); box.heightAnchor.constraint(equalToConstant: 150).isActive = true; add(box)
        details.font = .monospacedSystemFont(ofSize: 12,weight: .regular); details.textColor = .secondaryLabelColor; details.maximumNumberOfLines = 3; add(details)
        let targetRow = NSStackView(); targetRow.orientation = .horizontal; targetRow.spacing = 12
        targetRow.addArrangedSubview(label("目标版本",13,.medium))
        targetPicker.addItems(withTitles: ["自动识别（降一级）", "Resolve 20", "Resolve 19"])
        targetPicker.target = self; targetPicker.action = #selector(targetChanged)
        targetRow.addArrangedSubview(targetPicker); add(targetRow)
        let folderRow = NSStackView(); folderRow.orientation = .horizontal; folderRow.spacing = 12
        folderLabel.font = .systemFont(ofSize: 12); folderLabel.textColor = .secondaryLabelColor; folderLabel.maximumNumberOfLines = 2
        folderLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        folderButton.target = self; folderButton.action = #selector(changeFolder); folderButton.bezelStyle = .rounded
        folderRow.addArrangedSubview(folderLabel); folderRow.addArrangedSubview(folderButton); add(folderRow)
        convertButton.target = self; convertButton.action = #selector(runConversion); convertButton.bezelStyle = .rounded; convertButton.controlSize = .large; convertButton.isEnabled = false; add(convertButton)
        let row = NSStackView(); row.orientation = .horizontal; row.spacing = 12; progress.style = .spinning; progress.controlSize = .small; progress.isDisplayedWhenStopped = false
        status.font = .systemFont(ofSize: 13); status.maximumNumberOfLines = 3; status.isSelectable = true; row.addArrangedSubview(progress); row.addArrangedSubview(status); add(row)
        reveal.target = self; reveal.action = #selector(revealResult); reveal.bezelStyle = .rounded; reveal.isEnabled = false; stack.addArrangedSubview(reveal)
        let note = label("自动降一级，或手动选 19 / 20；21 → 19 为实验选项。仅调整版本标记，新版专属效果仍需在目标版本中检查。输出为 .drp；若素材离线，请链接原归档的 MediaFiles 文件夹。",12); note.textColor = .secondaryLabelColor; add(note)
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if let url = pending { load(url) }
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let first = filenames.first else {return}; let url = URL(fileURLWithPath: first)
        if window == nil { pending = url } else { load(url) }; sender.reply(toOpenOrPrint: .success)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    @objc func about() { let a = NSAlert(); a.messageText = "达芬奇工程兼容工具 1.3.3（内置运行环境）"; a.informativeText = "Resolve 21 → 20 / 20 → 19 实验兼容补丁。\n本地转换，不上传工程；不修改原文件。\n并非完整数据结构迁移。\n\n版权所有 © 2026 Jzero。保留所有权利。\nCopyright © 2026 Jzero. All rights reserved."; a.runModal() }
    @objc func selectFile() {
        guard !busy else { return }
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; panel.treatsFilePackagesAsDirectories = false; panel.message = "选择 .dra 归档文件夹或 .drp 工程"
        panel.beginSheetModal(for: window) { [weak self] response in if response == .OK,let url = panel.url { self?.load(url) } }
    }
    func work(_ args: [String], completion: @escaping ([String:Any])->Void) {
        busy = true; targetPicker.isEnabled = false; folderButton.isEnabled = false; choose.isEnabled = false; convertButton.isEnabled = false; progress.startAnimation(nil)
        let resources = Bundle.main.resourceURL!
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process(); process.executableURL = resources.appendingPathComponent("runtime/bin/python3.12"); process.arguments = ["-I", "-B", resources.appendingPathComponent("worker.py").path] + args
            var env = ProcessInfo.processInfo.environment; env["PYTHONIOENCODING"] = "utf-8"; env["PYTHONUTF8"] = "1"; env["PYTHONDONTWRITEBYTECODE"] = "1"; process.environment = env
            let pipe = Pipe(); let errors = Pipe(); process.standardOutput = pipe; process.standardError = errors
            var response: [String:Any]
            do {
                try process.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); let err = errors.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
                response = (try? JSONSerialization.jsonObject(with: data)) as? [String:Any] ?? ["ok":false,"error":String(data:err,encoding:.utf8) ?? "转换进程未返回结果"]
            } catch { response = ["ok":false,"error":error.localizedDescription] }
            DispatchQueue.main.async { self.busy = false; self.targetPicker.isEnabled = true; self.folderButton.isEnabled = true; self.choose.isEnabled = true; self.progress.stopAnimation(nil); completion(response) }
        }
    }
    var selectedTarget: String { targetPicker.indexOfSelectedItem == 1 ? "20" : targetPicker.indexOfSelectedItem == 2 ? "19" : "auto" }
    @objc func targetChanged() { if let url = source { load(url) } }
    @objc func changeFolder() {
        guard !busy else { return }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.directoryURL = outputFolder; panel.prompt = "使用此文件夹"
        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url { self.outputFolder = url; self.folderLabel.stringValue = "输出位置：" + url.path }
        }
    }
    func load(_ url: URL) {
        guard !busy else { return }
        if source != url || outputFolder == nil { outputFolder = url.deletingLastPathComponent() }
        folderLabel.stringValue = "输出位置：" + outputFolder!.path
        source = url; convertButton.title = "生成兼容副本"; result = nil; reveal.isEnabled = false; status.textColor = .secondaryLabelColor; status.stringValue = "正在检查工程…"; filename.stringValue = url.lastPathComponent; path.stringValue = url.path; details.stringValue = "正在读取工程版本与校验文件…"
        work(["inspect",url.path,selectedTarget]) { data in
            guard data["ok"] as? Bool == true else { self.details.stringValue = "当前目标不可用，请调整目标版本或重新选择工程。"; self.fail(data); return }
            self.experimental = data["experimental"] as? Bool == true
            let supported = data["supported"] as? Bool == true
            self.targetMajor = data["target_major"] as? Int ?? 20
            self.convertButton.title = "生成兼容副本"
            self.details.stringValue = "保存版本：\(data["app"] ?? "未知")    工程版本：\(data["version"] ?? "未知") → \(data["target_schema"] ?? "—")\n\(data["name"] ?? "")    实际目标：Resolve \(self.targetMajor)"
            self.convertButton.isEnabled = supported
            self.status.stringValue = supported ? (self.experimental ? "21 → 19 为实验转换，尚未在 Resolve 19 验证此路径。" : "检查通过，将在原工程旁生成副本；可更改位置。") : "仅支持 21 → 20、20 → 19；此工程未做修改。"
        }
    }
    func fail(_ data: [String:Any]) { status.textColor = .systemOrange; status.stringValue = "未完成：\(data["error"] ?? "未知错误")" }
    @objc func runConversion() {
        guard !busy, let source = source else {return}
        let folder = outputFolder ?? source.deletingLastPathComponent()
            let stem = source.deletingPathExtension().lastPathComponent + "_Resolve\(self.targetMajor)_兼容"
            var output = folder.appendingPathComponent(stem + ".drp"); var i = 2
            while FileManager.default.fileExists(atPath: output.path) || FileManager.default.fileExists(atPath: output.deletingPathExtension().appendingPathExtension("report.json").path) { output = folder.appendingPathComponent(stem + "_\(i).drp"); i += 1 }
            self.status.stringValue = "正在生成副本并校验，稍候…"
            self.work(["convert",source.path,output.path,String(self.targetMajor)]) { data in
                self.convertButton.isEnabled = true
                guard data["ok"] as? Bool == true else {self.fail(data);return}
                self.result = output; self.reveal.isEnabled = true; self.status.textColor = .systemGreen
                self.status.stringValue = "已生成 \(output.lastPathComponent)\n请在 Resolve \(self.targetMajor) 中导入并检查。此结果尚未经 Resolve 验证。"
                self.path.stringValue = source.path
            }
    }
    @objc func revealResult() { if let url = result { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
