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
    var targetPicker: NSPopUpButton!
    var folderLabel: NSTextField!
    var folderButton: NSButton!
    var experimental = false
    var busy = false
    var pending: URL?
    var filename: NSTextField!
    var path: NSTextField!
    var details: NSTextField!
    var status: NSTextField!
    var choose: NSButton!
    var convertButton: NSButton!
    var reveal: NSButton!
    var progress: NSProgressIndicator!

    func label(_ string: String, _ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSTextField {
        let v = NSTextField(wrappingLabelWithString: string); v.font = .systemFont(ofSize: size, weight: weight); return v
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildWindow()
        if let url = pending { load(url); pending = nil }
    }

    var english: Bool {
        UserDefaults.standard.string(forKey: "interfaceLanguage") == "en"
    }

    func tr(_ chinese: String, _ englishText: String) -> String {
        english ? englishText : chinese
    }

    func buildWindow(targetIndex: Int = 0) {
        targetPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        folderLabel = NSTextField(wrappingLabelWithString: tr("输出位置：默认保存在原工程旁边", "Output: next to the source project"))
        folderButton = NSButton(title: tr("更改位置…", "Change Location…"), target: nil, action: nil)
        filename = NSTextField(labelWithString: tr("拖入 .dra 或 .drp 工程", "Drop a .dra or .drp project here"))
        path = NSTextField(wrappingLabelWithString: tr("也可以点击下方按钮，选择本机或挂载磁盘中的工程。", "Or choose a project from this Mac or a mounted drive."))
        details = NSTextField(wrappingLabelWithString: tr("选择工程后，将检查保存版本与文件完整性。", "Choose a project to check its version and file integrity."))
        status = NSTextField(wrappingLabelWithString: tr("等待选择工程", "Waiting for a project"))
        choose = NSButton(title: tr("选择工程…", "Choose Project…"), target: nil, action: nil)
        convertButton = NSButton(title: tr("生成兼容副本", "Create Compatibility Copy"), target: nil, action: nil)
        reveal = NSButton(title: tr("在访达中显示", "Show in Finder"), target: nil, action: nil)
        progress = NSProgressIndicator()
        let menu = NSMenu(); let item = NSMenuItem(); menu.addItem(item)
        let appMenu = NSMenu(); appMenu.addItem(withTitle: tr("关于达芬奇工程兼容工具", "About DaVinci Resolve Compat"), action: #selector(about), keyEquivalent: "")
        appMenu.addItem(.separator()); appMenu.addItem(withTitle: tr("退出", "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); item.submenu = appMenu
        let file = NSMenuItem(); menu.addItem(file); let fileMenu = NSMenu(title: tr("文件", "File")); fileMenu.addItem(withTitle: tr("选择工程…", "Choose Project…"), action: #selector(selectFile), keyEquivalent: "o"); file.submenu = fileMenu
        let edit = NSMenuItem(); menu.addItem(edit); let editMenu = NSMenu(title: tr("编辑", "Edit"))
        editMenu.addItem(withTitle: tr("复制", "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c"); editMenu.addItem(withTitle: tr("全选", "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"); edit.submenu = editMenu
        let language = NSMenuItem()
        menu.addItem(language)
        let languageMenu = NSMenu(title: tr("语言", "Language"))
        for (title, code) in [("简体中文", "zh-Hans"), ("English", "en")] {
            let option = languageMenu.addItem(withTitle: title, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            option.target = self
            option.representedObject = code
            option.state = (english ? code == "en" : code == "zh-Hans") ? .on : .off
        }
        language.submenu = languageMenu
        NSApp.mainMenu = menu
        window = window ?? NSWindow(contentRect: NSRect(x: 0,y: 0,width: 740,height: 735), styleMask: [.titled,.closable,.miniaturizable], backing: .buffered, defer: false)
        window.title = tr("达芬奇工程兼容工具", "DaVinci Resolve Compat"); window.appearance = NSAppearance(named: .darkAqua)
        let root = DropView(frame: NSRect(x: 0,y: 0,width: 740,height: 735)); root.onDrop = { [weak self] in self?.load($0) }; window.contentView = root
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 19; stack.translatesAutoresizingMaskIntoConstraints = false; root.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: root.leadingAnchor,constant: 32), stack.trailingAnchor.constraint(equalTo: root.trailingAnchor,constant: -32),stack.topAnchor.constraint(equalTo: root.topAnchor,constant: 28)])
        func add(_ view: NSView) { stack.addArrangedSubview(view); view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        let eyebrow = label("RESOLVE PROJECT COMPATIBILITY",11,.semibold); eyebrow.textColor = .secondaryLabelColor; add(eyebrow)
        add(label(tr("让工程兼容旧版 Resolve", "Open Projects in Older Resolve Versions"),28,.semibold))
        let subtitle = label(tr("21 → 20 / 20 → 19  ·  本地处理  ·  原工程保持不变", "21 → 20 / 20 → 19  ·  Local processing  ·  Preserves the original"),13); subtitle.textColor = .secondaryLabelColor; add(subtitle)
        let box = NSBox(); box.title = tr("源工程", "Source Project"); box.boxType = .custom; box.borderColor = .separatorColor; box.borderWidth = 1; box.cornerRadius = 10; box.contentViewMargins = NSSize(width: 20,height: 18)
        let inside = NSStackView(); inside.orientation = .vertical; inside.alignment = .leading; inside.spacing = 10; inside.translatesAutoresizingMaskIntoConstraints = false
        box.contentView!.addSubview(inside); NSLayoutConstraint.activate([inside.leadingAnchor.constraint(equalTo: box.contentView!.leadingAnchor,constant: 18),inside.trailingAnchor.constraint(equalTo: box.contentView!.trailingAnchor,constant: -18),inside.topAnchor.constraint(equalTo: box.contentView!.topAnchor,constant: 18),inside.bottomAnchor.constraint(equalTo: box.contentView!.bottomAnchor,constant: -18)])
        filename.font = .systemFont(ofSize: 17,weight: .medium); filename.lineBreakMode = .byTruncatingMiddle
        path.font = .systemFont(ofSize: 12); path.textColor = .secondaryLabelColor; path.isSelectable = true; path.maximumNumberOfLines = 3
        choose.target = self; choose.action = #selector(selectFile); choose.bezelStyle = .rounded
        inside.addArrangedSubview(filename); inside.addArrangedSubview(path); inside.addArrangedSubview(choose); box.heightAnchor.constraint(equalToConstant: 150).isActive = true; add(box)
        details.font = .monospacedSystemFont(ofSize: 12,weight: .regular); details.textColor = .secondaryLabelColor; details.maximumNumberOfLines = 3; add(details)
        let targetRow = NSStackView(); targetRow.orientation = .horizontal; targetRow.spacing = 12
        targetRow.addArrangedSubview(label(tr("目标版本", "Target Version"),13,.medium))
        targetPicker.addItems(withTitles: [tr("自动识别（降一级）", "Auto (One Version Back)"), "Resolve 20", "Resolve 19"])
        targetPicker.selectItem(at: targetIndex)
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
        let note = label(tr("自动降一级，或手动选 19 / 20；21 → 19 为实验选项。仅调整版本标记，新版专属效果仍需在目标版本中检查。输出为 .drp；若素材离线，请链接原归档的 MediaFiles 文件夹。", "Auto goes back one version. Choose 19 or 20 manually if needed. 21 → 19 is experimental. The tool patches version markers and exports a .drp. Check effects in the target version and relink MediaFiles if media is offline."),12); note.textColor = .secondaryLabelColor; add(note)
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc func changeLanguage(_ item: NSMenuItem) {
        guard !busy, window.attachedSheet == nil, let code = item.representedObject as? String,
              (code == "en") != english else { return }
        let targetIndex = targetPicker.indexOfSelectedItem
        let previousResult = result
        UserDefaults.standard.set(code, forKey: "interfaceLanguage")
        buildWindow(targetIndex: targetIndex)
        if let url = source { load(url, preserving: previousResult) }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let first = filenames.first else {return}; let url = URL(fileURLWithPath: first)
        if window == nil { pending = url } else { load(url) }; sender.reply(toOpenOrPrint: .success)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    @objc func about() {
        let alert = NSAlert()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        alert.messageText = tr("达芬奇工程兼容工具", "DaVinci Resolve Compat") + " " + version
        alert.informativeText = tr(
            "本地转换，保留原工程。工具仅修改版本标记。\n\n版权所有 © 2026 Jzero。保留所有权利。",
            "Local conversion preserves the original project. The tool patches version markers.\n\nCopyright © 2026 Jzero. All rights reserved."
        )
        alert.runModal()
    }
    @objc func selectFile() {
        guard !busy else { return }
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; panel.treatsFilePackagesAsDirectories = false; panel.message = tr("选择 .dra 归档文件夹或 .drp 工程", "Choose a .dra archive folder or a .drp project.")
        panel.beginSheetModal(for: window) { [weak self] response in if response == .OK,let url = panel.url { self?.load(url) } }
    }
    func work(_ args: [String], completion: @escaping ([String:Any])->Void) {
        busy = true; targetPicker.isEnabled = false; folderButton.isEnabled = false; choose.isEnabled = false; convertButton.isEnabled = false; progress.startAnimation(nil)
        let resources = Bundle.main.resourceURL!
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process(); process.executableURL = resources.appendingPathComponent("runtime/bin/python3.12"); process.arguments = ["-I", "-B", resources.appendingPathComponent("worker.py").path] + args
            var env = ProcessInfo.processInfo.environment; env["RESOLVE_COMPAT_LANGUAGE"] = self.english ? "en" : "zh-Hans"; env["PYTHONIOENCODING"] = "utf-8"; env["PYTHONUTF8"] = "1"; env["PYTHONDONTWRITEBYTECODE"] = "1"; process.environment = env
            let pipe = Pipe(); let errors = Pipe(); process.standardOutput = pipe; process.standardError = errors
            var response: [String:Any]
            do {
                try process.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); let err = errors.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
                response = (try? JSONSerialization.jsonObject(with: data)) as? [String:Any] ?? ["ok":false,"error":String(data:err,encoding:.utf8) ?? self.tr("转换进程未返回结果", "The converter returned no result.")]
            } catch { response = ["ok":false,"error":error.localizedDescription] }
            DispatchQueue.main.async { self.busy = false; self.targetPicker.isEnabled = true; self.folderButton.isEnabled = true; self.choose.isEnabled = true; self.progress.stopAnimation(nil); completion(response) }
        }
    }
    var selectedTarget: String { targetPicker.indexOfSelectedItem == 1 ? "20" : targetPicker.indexOfSelectedItem == 2 ? "19" : "auto" }
    @objc func targetChanged() { if let url = source { load(url) } }
    @objc func changeFolder() {
        guard !busy else { return }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.directoryURL = outputFolder; panel.prompt = tr("使用此文件夹", "Use This Folder")
        panel.beginSheetModal(for: window) { response in
            if response == .OK, let url = panel.url { self.outputFolder = url; self.folderLabel.stringValue = self.tr("输出位置：", "Output: ") + url.path }
        }
    }
    func load(_ url: URL, preserving previousResult: URL? = nil) {
        guard !busy else { return }
        if source != url || outputFolder == nil { outputFolder = url.deletingLastPathComponent() }
        folderLabel.stringValue = tr("输出位置：", "Output: ") + outputFolder!.path
        source = url; convertButton.title = tr("生成兼容副本", "Create Compatibility Copy"); result = nil; reveal.isEnabled = false; status.textColor = .secondaryLabelColor; status.stringValue = tr("正在检查工程…", "Checking project…"); filename.stringValue = url.lastPathComponent; path.stringValue = url.path; details.stringValue = tr("正在读取工程版本与校验文件…", "Reading the project version and checking file integrity…")
        work(["inspect",url.path,selectedTarget]) { data in
            guard data["ok"] as? Bool == true else { self.details.stringValue = self.tr("当前目标不可用，请调整目标版本或重新选择工程。", "The current target is unavailable. Choose another target or project."); self.fail(data); return }
            self.experimental = data["experimental"] as? Bool == true
            let supported = data["supported"] as? Bool == true
            self.targetMajor = data["target_major"] as? Int ?? 20
            self.convertButton.title = self.tr("生成兼容副本", "Create Compatibility Copy")
            let saved = data["app"] ?? "—"
            let schema = data["version"] ?? "—"
            let name = data["name"] ?? ""
            let target = supported ? "Resolve \(self.targetMajor)" : "—"
            self.details.stringValue = self.tr(
                "保存版本：\(saved)    工程版本：\(schema) → \(data["target_schema"] ?? "—")\n\(name)    实际目标：\(target)",
                "Saved with: \(saved)    Project version: \(schema) → \(data["target_schema"] ?? "—")\n\(name)    Resolved target: \(target)"
            )
            self.convertButton.isEnabled = supported
            self.status.stringValue = supported ? (self.experimental ? self.tr("21 → 19 为实验转换，尚未在 Resolve 19 验证此路径。", "21 → 19 is experimental and has yet to be verified in Resolve 19.") : self.tr("检查通过，将在原工程旁生成副本；可更改位置。", "Project checked. Create a copy in the selected output folder.")) : self.tr("仅支持 21 → 20、20 → 19；此工程未做修改。", "This project version is unsupported.")
            if supported, let previousResult { self.showResult(previousResult) }
        }
    }
    func showResult(_ output: URL) {
        result = output
        reveal.isEnabled = true
        status.textColor = .systemGreen
        status.stringValue = tr(
            "已生成 \(output.lastPathComponent)\n请在 Resolve \(targetMajor) 中导入并检查。此结果尚未经 Resolve 验证。",
            "Created \(output.lastPathComponent)\nImport and check it in Resolve \(targetMajor). This copy has yet to be verified in Resolve."
        )
    }
    func fail(_ data: [String:Any]) { status.textColor = .systemOrange; status.stringValue = tr("未完成：", "Failed: ") + "\(data["error"] ?? tr("未知错误", "Unknown error"))" }
    @objc func runConversion() {
        guard !busy, let source = source else {return}
        let folder = outputFolder ?? source.deletingLastPathComponent()
            let stem = source.deletingPathExtension().lastPathComponent + "_Resolve\(self.targetMajor)_" + tr("兼容", "compat")
            var output = folder.appendingPathComponent(stem + ".drp"); var i = 2
            while FileManager.default.fileExists(atPath: output.path) || FileManager.default.fileExists(atPath: output.deletingPathExtension().appendingPathExtension("report.json").path) { output = folder.appendingPathComponent(stem + "_\(i).drp"); i += 1 }
            self.status.stringValue = self.tr("正在生成副本并校验，稍候…", "Creating and verifying the copy…")
            self.work(["convert",source.path,output.path,String(self.targetMajor)]) { data in
                self.convertButton.isEnabled = true
                guard data["ok"] as? Bool == true else {self.fail(data);return}
                self.showResult(output)
                self.path.stringValue = source.path
            }
    }
    @objc func revealResult() { if let url = result { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
