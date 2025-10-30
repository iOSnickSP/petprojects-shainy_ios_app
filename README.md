# SHAiny - Secure Encrypted Messaging for iOS

<div align="center">

![iOS](https://img.shields.io/badge/iOS-15.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-3.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)

**End-to-end encrypted messaging with SHA-256 integrity verification**

</div>

## ✨ Features

- 🔐 **End-to-End Encryption** - AES-256-CBC encryption for all private messages
- 🔗 **SHA-256 Integrity** - Every message is hashed to ensure integrity
- ⚡ **Real-Time Messaging** - WebSocket-based instant communication
- 🔔 **Push Notifications** - APNs integration with accurate badge counts
- 🎭 **Anonymous Auth** - Code phrase-based authentication system
- 🏷️ **Custom Chat Names** - Encrypted names for better organization
- 📱 **Modern UI** - Beautiful SwiftUI interface with dark mode

## 🚀 Quick Start

### Prerequisites

- Xcode 15.0 or later
- iOS 15.0+ device or simulator
- Apple Developer account (for push notifications)
- Backend server running (see `backend/README.md`)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd SHAiny
   ```

2. **Open in Xcode**
   ```bash
   open SHAiny.xcodeproj
   ```

3. **Configure backend URL**
   
   Update in `Services/SettingsService.swift`:
   ```swift
   private let defaultServerURL = "https://your-server.com"
   private let defaultWebSocketURL = "wss://your-server.com/ws"
   ```

4. **Configure APNs** (for push notifications)
   - Add `apns-key.p8` to `backend/` directory
   - Update `backend/env` with APNs configuration
   - Ensure `SHAiny.entitlements` has push notifications capability

5. **Build and run** (⌘+R)

### Getting Started as a User

1. Launch the app
2. Enter a code phrase from an existing user
3. Start messaging!

## 📖 Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Complete architecture overview, security model, and design patterns
- **[COMPONENTS.md](./COMPONENTS.md)** - Detailed reference for all components, services, and utilities
- **[MOBILE_SETUP.md](./MOBILE_SETUP.md)** - Mobile setup instructions
- **[APNS_SETUP.md](./APNS_SETUP.md)** - Push notification configuration

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│           SwiftUI Views                  │
│   (ContentView, ChatView, LoginView)    │
└──────────────┬──────────────────────────┘
               │ @ObservedObject
┌──────────────▼──────────────────────────┐
│          ViewModels (MVVM)               │
│  (ChatListVM, ChatVM, AuthVM)           │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│            Services                      │
│  (ChatService, WebSocketService, etc)   │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│    Network / Storage / Crypto           │
│  (URLSession, Keychain, CryptoUtils)    │
└─────────────────────────────────────────┘
```

**Pattern**: MVVM (Model-View-ViewModel)  
**Reactive**: Combine framework  
**Navigation**: SwiftUI NavigationView

## 📁 Project Structure

```
SHAiny/
├── Models/                     # Data models
│   ├── Chat.swift             # Chat room model
│   ├── Message.swift          # Message model
│   ├── AuthState.swift        # Auth state enum
│   └── ChatConnectionState.swift
│
├── Views/                     # SwiftUI views
│   ├── Components/            # Reusable UI components
│   ├── ContentView.swift     # Main chat list
│   ├── ChatView.swift        # Chat conversation
│   └── LoginView.swift       # Authentication
│
├── ViewModels/                # View models (MVVM)
│   ├── AuthViewModel.swift
│   ├── ChatListViewModel.swift
│   └── ChatViewModel.swift
│
├── Services/                  # Business logic
│   ├── AuthService.swift     # Authentication API
│   ├── ChatService.swift     # Chat management API
│   ├── WebSocketService.swift # Real-time messaging
│   ├── NotificationService.swift # Push notifications
│   ├── BadgeManager.swift    # Centralized badge management
│   ├── KeychainService.swift # Secure storage
│   └── SettingsService.swift # App settings
│
├── Utils/                     # Utilities
│   ├── CryptoUtils.swift     # Encryption/hashing
│   └── Driver.swift          # Combine wrapper
│
└── SHAinyApp.swift           # App entry point
```

## 🔒 Security

### Encryption

- **Algorithm**: AES-256-CBC with PKCS7 padding
- **Key Derivation**: PBKDF2 from user-provided key phrases
- **IV**: Random IV per message, prepended to ciphertext

### Integrity

- **Hashing**: SHA-256 of plaintext message
- **Verification**: Hash checked after decryption
- **Tamper Detection**: Hash mismatch indicates message corruption

### Storage

- **Keychain**: Access tokens (JWT), encryption keys (with auto-migration from UserDefaults)
- **UserDefaults**: Settings, nicknames
- **No Cloud Sync**: All data stays on device

### Limitations (MVP)

⚠️ No key rotation or Perfect Forward Secrecy  
⚠️ Server sees chat participation metadata

See [ARCHITECTURE.md](./ARCHITECTURE.md#security-considerations) for details.

## 🛠️ Development

### Requirements

- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+
- iOS 15.0+ deployment target

### Building

```bash
# Open project
open SHAiny.xcodeproj

# Build for simulator
xcodebuild -scheme SHAiny -sdk iphonesimulator

# Run tests
xcodebuild test -scheme SHAiny -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Code Style

- SwiftLint enforced
- 4-space indentation
- Descriptive names
- Comments for complex logic

### Testing

```bash
# Unit tests
⌘+U in Xcode

# UI tests
⌘+U with UI testing scheme
```

## 🐛 Debugging

### Enable Encrypted Data Display

1. Open app
2. Go to Profile → Display Settings
3. Toggle "Show Encrypted Data"
4. Messages will now show:
   - Encrypted text
   - SHA-256 hash
   - Decrypted text

### Console Logs

All services log with emojis for easy filtering:
- 🔐 Authentication
- 💬 Chat operations
- 📤 Sending messages
- 📩 Receiving messages
- 🔢 Badge updates
- 🔄 Badge synchronization
- ✅ Success
- ❌ Errors

## 📱 Screenshots

*(Add screenshots here)*

## 🤝 Contributing

Contributions welcome! Please follow:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

### Development Workflow

- Feature branches from `main`
- Pull requests required
- Code review by at least one person
- All tests must pass
- SwiftLint checks must pass

## 📝 Roadmap

### v1.0 (Current - MVP)
- [x] End-to-end encryption
- [x] Real-time messaging
- [x] Push notifications
- [x] Chat creation/joining
- [x] Custom chat names
- [x] User nicknames

### v1.1 (Planned)
- [ ] Message search
- [ ] File/image sharing (encrypted)
- [ ] Message reactions
- [ ] Group administration (kick/ban)
- [ ] Self-destructing messages

### v2.0 (Future)
- [ ] Voice messages
- [ ] Video calls
- [ ] Signal Protocol integration
- [ ] Biometric authentication
- [ ] macOS version
- [ ] watchOS companion app

## ⚡ Performance

### Optimizations

- `LazyVStack` for message lists (efficient rendering)
- Pagination (50 messages per page)
- WebSocket for real-time (no polling)
- Optimistic UI updates
- UUID preservation during reloads

### Memory Management

- Weak references in closures
- Cancellable subscriptions cleanup
- View disappear lifecycle handling

## 🔧 Troubleshooting

### Common Issues

**"Failed to decrypt message"**
- Wrong encryption key
- Verify key phrase is correct
- Check SHA hash mismatch in logs

**"WebSocket not connected"**
- Network connection issue
- Token expired
- Check authentication state

**"Chat key not found"**
- Encryption key missing
- Rejoin chat with correct key phrase

**Push notifications not working**
- Check APNs configuration
- Verify entitlements
- Check device token registration

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Team

Created by Sergey Vikhlyaev

## 🙏 Acknowledgments

- SwiftUI community
- CryptoKit documentation
- Apple Developer documentation

## 📧 Support

For questions or issues:
- Open an issue on GitHub
- Contact: [contact information]

---

<div align="center">

**Built with ❤️ using Swift and SwiftUI**

[Report Bug](issues) · [Request Feature](issues)

</div>

