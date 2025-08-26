# UnionToast

A toast notification system for SwiftUI that provides seamless presentation across your app.

## Features

- 🎯 **Simple API**: SwiftUI `.toast(isPresented:)` modifier
- 🪟 **Overlay Windows**: Uses passthrough overlay windows for proper presentation
- 🎨 **Fully Customizable**: Support for any SwiftUI content
- ⏰ **Auto-dismiss**: Built-in timing with pause/resume on interaction
- 📱 **Gesture Support**: Swipe up to dismiss, hold to pause timer
- ✨ **Smooth Animations**: Beautiful transitions and animations
- 🚀 **Pure SwiftUI**: Built entirely with SwiftUI

## Installation

Add this package to your project using Swift Package Manager:

```swift
.package(url: "https://github.com/unionst/union-toast.git", from: "1.0.0")
```

## Usage

### Basic Custom Toast

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
        .toast(isPresented: $showToast) {
            Text("Hello, World!")
                .padding()
                .background(.blue)
                .cornerRadius(8)
                .foregroundColor(.white)
        }
    }
}
```

### Advanced Custom Toast

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
    .padding()
    .background(.green)
    .cornerRadius(12)
    .foregroundColor(.white)
}
```

## Behavior

The toast system automatically configures overlay windows when first used. Toasts appear at the top of the screen and:

- **Auto-dismiss after ~6.5 seconds**
- **Can be dismissed by swiping up**
- **Timer pauses when user interacts with the toast**
- **Smooth animations and transitions**
- **Only one toast is shown at a time** (new toasts replace existing ones)

## Public API

- `View.toast(isPresented:content:)` - Present a toast with custom SwiftUI content

## Requirements

- iOS 17.0+
- Swift 6.0+

## Dependencies

- [UnionScroll](https://github.com/unionst/union-scroll) - For scroll behavior


