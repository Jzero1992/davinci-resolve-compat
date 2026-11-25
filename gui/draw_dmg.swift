import AppKit
let image = NSImage(size:NSSize(width:820,height:560));image.lockFocus()
NSColor(calibratedWhite:0.12,alpha:1).setFill();NSRect(x:0,y:0,width:820,height:560).fill()
func text(_ s:String,_ x:CGFloat,_ top:CGFloat,_ w:CGFloat,_ h:CGFloat,_ size:CGFloat,_ color:NSColor,_ weight:NSFont.Weight = .regular) {
 let para=NSMutableParagraphStyle();para.lineSpacing=5
 (s as NSString).draw(in:NSRect(x:x,y:560-top-h,width:w,height:h),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color,.paragraphStyle:para])
}
text("达芬奇工程兼容工具",42,30,730,50,30,.white,.semibold)
text("内置运行环境 · 无需另装 Python 或开发工具",44,88,730,32,15,NSColor(calibratedWhite:0.76,alpha:1))
text("Apple 芯片 Mac · macOS 12 及以上",44,119,730,30,13,NSColor(calibratedWhite:0.60,alpha:1))
text("→",382,186,80,80,54,NSColor(calibratedWhite:0.60,alpha:1))
text("拖入“应用程序”，再从应用程序中打开",180,298,620,40,16,.white,.medium)
NSColor(calibratedWhite:0.28,alpha:1).setFill();NSRect(x:42,y:210,width:736,height:1).fill()
text("首次打开被系统拦截？",44,370,520,35,18,.white,.semibold)
text("1. 先尝试打开 App，再进入“系统设置”。\n2. 打开“隐私与安全性”，找到本应用的拦截提示。\n3. 确认应用名称和来源后，点“仍要打开”。",44,415,550,95,14,NSColor(calibratedWhite:0.82,alpha:1))
text("详细说明 →",565,454,95,30,12,NSColor(calibratedWhite:0.62,alpha:1))
image.unlockFocus();let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!;try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
