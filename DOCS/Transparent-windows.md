## Opaque → transparent windows

### AppDelegate

Lines 86-88

```swift

        // MARK: transparent window -----------------------------------------
        
        // Enable translucent liquid-glass style (Tahoe): the SwiftUI content
        // supplies material backgrounds (.regularMaterial / .ultraThinMaterial),
        // so the window itself is kept transparent and non-opaque.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        
        // END: transparent window -----------------------------------------
```

### ContentView

Lines 74, 75, 86, 87

```swift
                //                .background(Color(NSColor.controlBackgroundColor)) // opaque window
                .background(.ultraThinMaterial) // transparent window

            // ── Detail ─────
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.ultraThickMaterial) // transparent window
        .toolbar {
```

### Settings View

Line 67

```swift
        .frame(width: 422, height: 334)
        .background(.ultraThickMaterial) // transparent window
        .onAppear {
            viewModel.loadCustomLogo()
        }
```

### SettingsWindowController

Lines 21, 22, 32-34

```swift

//        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable] // opaque window
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView] // transparent window
        
        // TRANSPARENT WINDOW ------------------------
        
        // Enable translucent liquid-glass style (Tahoe): the SwiftUI content
        // supplies a material background (.regularMaterial), so the window
        // itself is kept transparent and non-opaque.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        
        // END ------------------------
```
