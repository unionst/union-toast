# UnionToast

A SwiftUI toast notification system that uses overlay windows for seamless presentation across your app.

## Features

- 🎯 **Simple API**: Use the `.toast(isPresented:)` modifier on any view
- 🪟 **Overlay Windows**: Uses passthrough overlay windows for proper presentation
- 🎨 **Customizable**: Support for text, icons, and custom views
- ⏰ **Auto-dismiss**: Configurable timing with pause/resume on interaction
- 📱 **Gesture Support**: Swipe up to dismiss, hold to pause timer
- 🔄 **Queue System**: Multiple toasts are queued and shown sequentially
- 🎵 **Haptic Feedback**: Built-in haptic feedback on toast presentation

## Installation

Add this package to your project using Swift Package Manager:

```swift
.package(url: "https://github.com/unionst/union-toast.git", from: "1.0.0")
```

## Usage

### Basic Text Toast

```swift
import UnionToast

struct ContentView: View {
    @State private var showToast = false
    
    var body: some View {
        VStack {
            Button("Show Toast") {
                showToast = true
            }
        }
        .toast(isPresented: $showToast, text: "Hello, World!")
    }
}
```

### Icon Toast

```swift
.toast(
    isPresented: $showToast,
    icon: Image(systemName: "checkmark.circle.fill"),
    text: "Success!"
)
```

### Custom Toast

```swift
.toast(isPresented: $showToast) {
    HStack {
        Image(systemName: "star.fill")
            .foregroundColor(.yellow)
        
        VStack(alignment: .leading) {
            Text("Achievement Unlocked!")
                .font(.headline)
            Text("You've completed your first task")
                .font(.caption)
        }
    }
    .foregroundColor(.white)
}
```

### Direct Toast Manager Usage

For more control, you can use the ToastManager directly:

```swift
import UnionToast

// Show a text toast
ToastManager.shared.showToast(.text("Direct toast message"))

// Show an icon toast
ToastManager.shared.showToast(.icon(Image(systemName: "heart.fill"), "Liked!"))

// Show a custom toast
ToastManager.shared.showToast(.view {
    CustomToastView()
})
```

## Configuration

The toast system automatically configures overlay windows when first used. Toasts appear at the top of the screen and can be:

- **Dismissed by swiping up**
- **Paused by holding down** (timer pauses after 500ms of continuous touch)
- **Auto-dismissed after 4 seconds** (configurable in ToastManager)

## Requirements

- iOS 17.0+
- Swift 6.0+

## Dependencies

- [UnionHaptics](https://github.com/unionst/union-haptics) - For haptic feedback


