import AppKit
let image = NSImage(size: NSSize(width: 1024,height: 1024))
image.lockFocus()
NSColor.clear.setFill(); NSRect(x:0,y:0,width:1024,height:1024).fill()
let base = NSBezierPath(roundedRect: NSRect(x:62,y:62,width:900,height:900),xRadius:204,yRadius:204)
NSGradient(starting:NSColor(calibratedWhite:0.24,alpha:1),ending:NSColor(calibratedWhite:0.08,alpha:1))!.draw(in:base,angle:-90)
NSColor(calibratedWhite:0.65,alpha:0.35).setStroke();base.lineWidth=4;base.stroke()
let palettes: [(NSColor,NSColor)] = [
(NSColor(calibratedRed:0.12,green:0.94,blue:1,alpha:1),NSColor(calibratedRed:0.02,green:0.47,blue:0.71,alpha:1)),
(NSColor(calibratedRed:0.98,green:0.98,blue:0.12,alpha:1),NSColor(calibratedRed:0.47,green:0.72,blue:0.07,alpha:1)),
(NSColor(calibratedRed:1,green:0.41,blue:0.43,alpha:1),NSColor(calibratedRed:0.74,green:0.08,blue:0.22,alpha:1))]
for i in 0..<3 {
 NSGraphicsContext.saveGraphicsState()
 let transform=AffineTransform(translationByX:512,byY:548);let t=NSAffineTransform(transform:transform);t.rotate(byDegrees:CGFloat(i*120));t.concat()
 let blade=NSBezierPath();blade.move(to:NSPoint(x:0,y:28))
 blade.curve(to:NSPoint(x:-108,y:211),controlPoint1:NSPoint(x:-40,y:86),controlPoint2:NSPoint(x:-115,y:134))
 blade.curve(to:NSPoint(x:108,y:211),controlPoint1:NSPoint(x:-108,y:355),controlPoint2:NSPoint(x:108,y:355))
 blade.curve(to:NSPoint(x:0,y:28),controlPoint1:NSPoint(x:115,y:134),controlPoint2:NSPoint(x:40,y:86));blade.close()
 NSGradient(starting:palettes[i].0,ending:palettes[i].1)!.draw(in:blade,angle:-90)
 NSGraphicsContext.restoreGraphicsState()
}
// Return arrow makes this compatibility utility distinct from the editor.
let arrow=NSBezierPath();arrow.move(to:NSPoint(x:771,y:371))
arrow.curve(to:NSPoint(x:292,y:281),controlPoint1:NSPoint(x:738,y:172),controlPoint2:NSPoint(x:446,y:130))
arrow.lineWidth=43;arrow.lineCapStyle = .round;arrow.lineJoinStyle = .round
NSColor(calibratedWhite:0.96,alpha:1).setStroke();arrow.stroke()
let head=NSBezierPath();head.move(to:NSPoint(x:294,y:184));head.line(to:NSPoint(x:280,y:290));head.line(to:NSPoint(x:386,y:284));head.lineWidth=43;head.lineCapStyle = .round;head.lineJoinStyle = .round;head.stroke()
image.unlockFocus()
let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!
try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
