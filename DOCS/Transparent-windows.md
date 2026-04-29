## Opaque → transparent windows

### AppDelegate

Lines 85-90

```swift
       window.title = "About This Hack"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 680, height: 420)
        
        // MARK: transparent window -----------------------------------------
        
        // Enable translucent liquid-glass style (Tahoe): the SwiftUI content
        // supplies material backgrounds (.regularMaterial / .ultraThinMaterial),
        // so the window itself is kept transparent and non-opaque.
//        window.isOpaque = false
//        window.backgroundColor = .clear
//        window.titlebarAppearsTransparent = true
        
        // END: transparent window -----------------------------------------
```

### ContentView

Lines 74, 85

```swift
                .background(Color(NSColor.controlBackgroundColor)) // opaque window
//                .background(.ultraThickMaterial) // transparent window
                .transition(.move(edge: .leading))

                Divider()
                    .transition(.opacity)
            }

            // ── Detail ─────
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
//        .background(.ultraThickMaterial) // transparent window
        .toolbar {
```

### Settings View

Line 67

```swift
        .frame(width: 422, height: 334)
//        .background(.ultraThickMaterial) // transparent window
        .onAppear {
            viewModel.loadCustomLogo()
        }
```

### SettingsWindowController

Lines 19, 20, 32-34

```swift
   // MARK: - Initialization
    convenience init() {
        // Create the window programmatically
        // Use the content height to match the SwiftUI view's frame
        let contentRect = NSRect(x: 0, y: 0, width: Self.windowWidth, height: Self.contentHeight)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable] // opaque window
//        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView] // transparent window
        let window = NSWindow(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
        
        // Configure window properties
        window.title = NSLocalizedString("settings.title", comment: "Custom logo settings")
        window.isReleasedWhenClosed = false
        
        // TRANSPARENT WINDOW ------------------------
        
        // Enable translucent liquid-glass style (Tahoe): the SwiftUI content
        // supplies a material background (.regularMaterial), so the window
        // itself is kept transparent and non-opaque.
//        window.isOpaque = false
//        window.backgroundColor = .clear
//        window.titlebarAppearsTransparent = true
        
        // END ------------------------
```
