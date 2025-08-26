# UnionToast

A toast notification system for both SwiftUI and UIKit that provides seamless presentation across your app.

## Features

- 🎯 **Simple APIs**: SwiftUI `.toast(isPresented:)` modifier and UIKit `presentToast(_:)` method
- 🪟 **Overlay Windows**: Uses passthrough overlay windows for proper presentation
- 🎨 **Fully Customizable**: Support for any SwiftUI content or UIKit view controllers
- ⏰ **Auto-dismiss**: Built-in timing with pause/resume on interaction
- 📱 **Gesture Support**: Swipe up to dismiss, hold to pause timer
- 🎵 **Haptic Feedback**: Built-in haptic feedback on toast presentation
- 🔄 **Cross-Platform**: Works with both SwiftUI and UIKit

## Installation

Add this package to your project using Swift Package Manager:

```swift
.package(url: "https://github.com/unionst/union-toast.git", from: "1.0.0")
```

## Usage

### SwiftUI

#### Basic Custom Toast

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

#### Advanced Custom Toast

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

### UIKit

#### Present Toast with View Controller

```swift
import UnionToast

class ViewController: UIViewController {
    @IBAction func showToastTapped(_ sender: UIButton) {
        let toastVC = MyCustomViewController()
        presentToast(toastVC, animated: true) {
            print("Toast presented!")
        }
    }
    
    @IBAction func dismissToastTapped(_ sender: UIButton) {
        dismissToast(animated: true) {
            print("Toast dismissed!")
        }
    }
}
```

#### Using UIHostingController for SwiftUI Content

```swift
let swiftUIView = Text("Hello from SwiftUI!")
    .padding()
    .background(.purple)
    .cornerRadius(8)
    .foregroundColor(.white)

let hostingController = UIHostingController(rootView: swiftUIView)
presentToast(hostingController, animated: true)
```

## Behavior

The toast system automatically configures overlay windows when first used. Toasts appear at the top of the screen and:

- **Auto-dismiss after ~6.5 seconds**
- **Can be dismissed by swiping up**
- **Timer pauses when user interacts with the toast**
- **Include haptic feedback on presentation**
- **Only one toast is shown at a time** (new toasts replace existing ones)

## Public API

### SwiftUI
- `View.toast(isPresented:content:)` - Present a toast with custom SwiftUI content

### UIKit  
- `UIViewController.presentToast(_:animated:completion:)` - Present a toast with a view controller
- `UIViewController.dismissToast(animated:completion:)` - Dismiss the current toast

## Requirements

- iOS 17.0+
- Swift 6.0+

## Dependencies

- [UnionHaptics](https://github.com/unionst/union-haptics) - For haptic feedback
- [UnionScroll](https://github.com/unionst/union-scroll) - For scroll behavior


