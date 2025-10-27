# SHAiny iOS Application - Architecture Documentation

## Overview

SHAiny is an iOS messaging application that provides end-to-end encrypted chat functionality using SHA-256 hashing and symmetric key encryption. The app supports both global announcement channels and private encrypted chats.

## Core Features

- **End-to-End Encryption**: All private messages are encrypted using AES-256-CBC with user-provided key phrases
- **SHA-256 Integrity**: Every message is hashed to ensure integrity and verify decryption
- **Real-time Messaging**: WebSocket-based real-time communication
- **Push Notifications**: APNs integration for message notifications
- **Anonymous Authentication**: Code phrase-based authentication system
- **Custom Chat Names**: Encrypted custom names for better organization

## Technology Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Minimum iOS Version**: iOS 15.0+
- **Architecture Pattern**: MVVM (Model-View-ViewModel)
- **Reactive Framework**: Combine
- **Networking**: URLSession (REST), URLSessionWebSocketTask (WebSocket)
- **Security**: CryptoKit, CommonCrypto
- **Local Storage**: Keychain (tokens), UserDefaults (settings, keys, nicknames)

## Project Structure

```
SHAiny/
├── Models/                          # Data models
│   ├── Chat.swift                   # Chat room model
│   ├── Message.swift                # Message model
│   ├── AuthState.swift              # Authentication state enum
│   └── ChatConnectionState.swift    # Chat connection flow state
│
├── Views/                           # SwiftUI views
│   ├── Components/                  # Reusable UI components
│   │   ├── ChatRowView.swift       # Chat list row
│   │   ├── MessageBubbleView.swift # Message bubble
│   │   ├── EmptyPrivateChatsView.swift
│   │   └── ExpandableSHAView.swift # Expandable hash/encrypted text
│   ├── ContentView.swift           # Main chat list view
│   ├── ChatView.swift              # Individual chat view
│   ├── ChatConnectionView.swift    # Join/create chat modal
│   ├── ChatInfoView.swift          # Chat details and settings
│   ├── LoginView.swift             # Authentication view
│   ├── ProfileView.swift           # User profile and settings
│   ├── DisplaySettingsView.swift   # Display preferences
│   └── SplashView.swift            # Loading splash screen
│
├── ViewModels/                      # View models (MVVM pattern)
│   ├── AuthViewModel.swift         # Authentication logic
│   ├── ChatListViewModel.swift     # Chat list management
│   ├── ChatViewModel.swift         # Individual chat logic
│   └── ProfileViewModel.swift      # Profile management
│
├── Services/                        # Business logic and API layers
│   ├── AuthService.swift           # Authentication API
│   ├── ChatService.swift           # Chat management API
│   ├── WebSocketService.swift      # Real-time messaging
│   ├── NotificationService.swift   # Push notifications (APNs)
│   ├── BadgeManager.swift          # Centralized badge management
│   ├── KeychainService.swift       # Secure token storage
│   ├── SettingsService.swift       # App settings
│   ├── ChatKeysStorage.swift       # Encryption keys storage
│   └── ChatNicknamesStorage.swift  # User nicknames storage
│
├── Utils/                           # Utilities and helpers
│   ├── CryptoUtils.swift           # Encryption/hashing functions
│   └── Driver.swift                # Combine property wrapper
│
├── SHAinyApp.swift                 # App entry point
├── Assets.xcassets/                # Images and colors
├── Info.plist                      # App configuration
└── SHAiny.entitlements            # Capabilities (push notifications)
```

## Architecture Patterns

### MVVM (Model-View-ViewModel)

The app follows the MVVM pattern strictly:

- **Models**: Pure data structures (structs) without business logic
- **Views**: SwiftUI views that observe ViewModels and render UI
- **ViewModels**: Business logic, state management, and coordination between Services

### Dependency Flow

```
Views → ViewModels → Services → Network/Storage
                    ↓
                  Models
```

### State Management

- **ViewModels**: Use `@Published` properties for reactive updates
- **Driver Property Wrapper**: Custom wrapper that ensures main thread delivery
- **Combine**: Publishers and subscribers for event streams
- **Environment Objects**: `AuthViewModel` is shared across the app

## Key Components

### Authentication Flow

```swift
AuthState:
  - loading     // Checking token validity
  - authenticated   // User has valid token
  - unauthenticated // User needs to log in
```

**Flow**:
1. App checks for stored access token in Keychain
2. Validates token with backend
3. If valid: connects WebSocket → shows ContentView
4. If invalid: shows LoginView

**Code Phrase System**:
- Users receive a code phrase from existing users
- Code phrase is used to login and get access token
- Token is stored securely in Keychain

### Chat System

#### Chat Types

1. **Global Chats** (`isGlobal: true`)
   - Announcements channel (read-only for most users)
   - Fixed encryption key: `"AnnouncementsSHAinyChat"`
   - All users automatically join

2. **Private Chats** (`isGlobal: false`)
   - User-created encrypted rooms
   - Require key phrase to join/create
   - Key phrase is hashed (SHA-256) and used as chat identifier
   - Encryption key is the original key phrase

#### Chat Creation/Joining Flow

```swift
ChatConnectionState:
  - checking          // Verifying if chat exists
  - exists(id, name)  // Chat found, can join
  - notExists         // No chat found, can create
  - error(message)    // Error occurred
```

**Flow**:
1. User enters key phrase
2. System generates SHA-256 hash of key phrase
3. Backend checks if chat with this hash exists
4. User either joins existing chat or creates new one
5. Key phrase stored locally for encryption/decryption

### Encryption System

**Message Encryption**: AES-256-CBC with PKCS7 padding

```swift
Encryption Flow:
1. User types message (plaintext)
2. Generate SHA-256 hash of plaintext
3. Encrypt plaintext using chat's key phrase (AES-256-CBC)
4. Send encrypted text + SHA hash to backend
5. Backend stores encrypted text and hash

Decryption Flow:
1. Receive encrypted text + SHA hash from backend
2. Decrypt using locally stored key phrase
3. Generate SHA-256 hash of decrypted text
4. Verify hash matches received hash
5. Display decrypted text to user
```

**Why SHA-256?**
- Integrity verification: ensures message wasn't tampered with
- Decryption validation: confirms correct key was used
- No reversibility: hash cannot be used to recover plaintext

### Real-Time Communication

**WebSocket Events**:

```swift
Outgoing:
- auth(token)                    // Authenticate connection
- sendMessage(chatId, encryptedText, shaHash)
- refreshChats                   // Request chat list update

Incoming:
- auth_success(userId)           // Authentication confirmed
- auth_error(message)            // Authentication failed
- new_message(chatId, message)   // New message received
- chats_updated                  // Chat list changed
- error(message)                 // Error occurred
```

**Message Flow**:
1. User types message → encrypts → sends via WebSocket
2. Backend validates, stores, broadcasts to chat participants
3. Recipients receive via WebSocket → decrypt → display
4. ChatListViewModel updates chat preview and unread count

### Notifications System

**APNs Integration**:

```swift
Flow:
1. Request notification permissions on app launch
2. Register device with APNs → receive device token
3. Send device token to backend
4. Backend stores token for user
5. When new message arrives:
   - Backend calculates total unread count for recipient
   - Sends push notification with accurate badge count
6. App receives notification:
   - If app open + chat open: just decrypt and show
   - If app open + chat closed: show in-app banner + update badge
   - If app closed: show system notification with badge
   - Badge automatically synced from payload
```

**Notification Payload**:
```json
{
  "aps": {
    "alert": {
      "title": "ChatName",
      "body": "SenderName: Message preview"
    },
    "badge": 5,
    "sound": "default"
  },
  "chatId": "chat-id-here"
}
```

### Badge Management System

**Centralized Architecture**:

The app uses `BadgeManager` as a single source of truth for badge count management.

```swift
BadgeManager (Singleton)
├── Tracks current badge count
├── Synchronizes with system badge on app lifecycle
├── Validates badge persistence (auto-restore if reset)
└── Integrates with chat unread counts

Backend Integration:
├── getTotalUnreadCount(userId) calculates across all chats
├── Badge sent in push notification payload
└── iOS syncs badge from remote notifications
```

**Key Features**:
- ✅ **Accurate Count**: Badge always reflects real unread messages across all chats
- ✅ **Auto-Sync**: Syncs with system on app launch and when becoming active
- ✅ **Race Condition Prevention**: Timestamp tracking prevents conflicting updates
- ✅ **Persistence Validation**: Checks badge wasn't reset by system after 150ms
- ✅ **Thread-Safe**: All operations guaranteed on main thread

**Badge Update Flow**:
```swift
1. New message arrives → ChatListViewModel updates unreadCount
2. ChatListViewModel calls BadgeManager.updateFromChats(chats)
3. BadgeManager calculates total: chats.reduce(0) { $0 + $1.unreadCount }
4. Sets UIApplication.shared.applicationIconBadgeNumber
5. Validates badge after 150ms, restores if mismatch detected
```

**Remote Notification Badge**:
```swift
1. Backend calculates db.getTotalUnreadCount(userId)
2. Includes badge in APNs payload
3. iOS displays notification with badge
4. App receives notification → BadgeManager syncs from payload
5. Badge count stays accurate even when app is closed
```

### Storage Architecture

**Keychain** (Secure):
- Access token (JWT)
- User ID extracted from token
- **Chat encryption keys** (keyed by chatId) - **UPDATED**: Now stored securely in Keychain

**UserDefaults** (Non-secure):
- Server URL setting
- Display preferences (show encrypted data)
- User nicknames per chat (keyed by chatId)
- Migration flag (for one-time migration from UserDefaults to Keychain)

**Chat Encryption Keys Storage**:
- ✅ **Now stored in Keychain** for proper security
- Protected by iOS encryption and device passcode/biometric
- Accessible only after device is unlocked (`kSecAttrAccessibleAfterFirstUnlock`)
- Automatic migration from old UserDefaults storage on first launch
- Keys deleted from Keychain on logout

## Data Models

### Chat Model

```swift
struct Chat: Identifiable {
    let id: UUID                    // SwiftUI list identifier
    let chatId: String              // Backend identifier
    let name: String                // Display name (decrypted if custom)
    let lastMessage: String?        // Preview text
    let lastMessageSender: String?  // Sender's nickname
    let timestamp: Date             // Last activity
    let participantsCount: Int      // Member count
    let isGlobal: Bool              // Is announcement channel
    let isReadOnly: Bool            // Can user send messages
    let encryptionKey: String?      // For encrypt/decrypt
    let hasCustomName: Bool         // Has encrypted name
    let unreadCount: Int            // Unread message count
}
```

### Message Model

```swift
struct Message: Identifiable, Equatable {
    let id: UUID                    // Message identifier
    let text: String                // Decrypted text (for display)
    let encryptedText: String       // Original encrypted text
    let shaHash: String             // SHA-256 hash (for verification)
    let timestamp: Date             // When sent
    let isFromCurrentUser: Bool     // For message bubble alignment
    let senderName: String?         // Sender's nickname
}
```

## ViewModels Deep Dive

### ChatListViewModel

**Responsibilities**:
- Load and display chat list
- Separate global and private chats
- Handle chat creation/joining
- Update chat previews from WebSocket
- Manage unread counts
- Sort chats (announcements first, then by timestamp)

**Key Features**:
- Preserves `UUID` during reload to prevent navigation issues
- Debounced sorting to avoid UI glitches during navigation
- Real-time updates from WebSocket messages

### ChatViewModel

**Responsibilities**:
- Load message history (paginated)
- Send new messages (encrypt → WebSocket)
- Receive real-time messages via WebSocket
- Manage nickname dialogs
- Handle chat renaming

**Key Features**:
- Driver property wrapper for reactive updates
- Pending message queue when nickname missing
- Automatic scroll to bottom on new messages

### AuthViewModel

**Responsibilities**:
- Check authentication on app launch
- Handle login with code phrase
- Logout and cleanup
- WebSocket lifecycle management

**Shared State**: Injected as `@EnvironmentObject` for app-wide access

## Security Considerations

### What's Secure

✅ **End-to-End Encryption**: Messages encrypted on device, server only stores ciphertext  
✅ **SHA-256 Integrity**: Message tampering detected via hash mismatch  
✅ **Token Storage**: Access tokens stored in Keychain  
✅ **Encryption Key Storage**: Chat encryption keys stored in Keychain (iOS protected)  
✅ **No Password Storage**: Authentication via one-time code phrases  
✅ **Transport Security**: HTTPS/WSS for all network communication  
✅ **Automatic Migration**: Old keys automatically migrated from UserDefaults to Keychain

### Current Limitations (MVP)

⚠️ **No Key Rotation**: Keys are static, never rotated  
⚠️ **No Perfect Forward Secrecy**: Same key for all messages  
⚠️ **Server Sees Chat Participation**: Metadata not hidden  
⚠️ **No Message Deletion**: Messages persist indefinitely  
⚠️ **Nicknames in UserDefaults**: User nicknames still in UserDefaults (could be moved)

### Future Security Enhancements

- Implement key rotation mechanism
- Add Perfect Forward Secrecy (Signal Protocol)
- Add biometric authentication for accessing chat keys
- Self-destructing messages
- Zero-knowledge architecture (hide metadata)
- Move nicknames to Keychain (optional, lower priority)

## API Integration

### REST Endpoints

**Authentication**:
- `POST /auth/login` - Login with code phrase
- `GET /auth/verify` - Verify token validity
- `POST /auth/generate-code` - Generate invite code

**Chat Management**:
- `GET /chat/list` - Get user's chats
- `POST /chat/check` - Check if chat exists
- `POST /chat/create` - Create new chat
- `POST /chat/:id/join` - Join existing chat
- `GET /chat/:id/messages` - Get message history
- `PUT /chat/:id/name` - Set encrypted chat name
- `POST /chat/:id/read` - Mark chat as read
- `POST /chat/:id/nickname` - Set user nickname
- `GET /chat/:id/nickname` - Get user nickname

**Notifications**:
- `POST /notifications/register` - Register device token
- `POST /notifications/unregister` - Unregister device

### WebSocket Protocol

**Connection**: `wss://server/ws`

**Message Format**: JSON

```json
{
  "type": "message_type",
  "payload": { ... }
}
```

## Performance Optimizations

### Message List
- `LazyVStack` for efficient rendering of large message lists
- Pagination (50 messages per page) to reduce memory usage
- Scroll-to-bottom optimization with `ScrollViewReader`

### Chat List
- UUID preservation prevents view recreation during updates
- Debounced sorting (100ms delay) prevents UI glitches
- Efficient filtering with computed properties (`globalChats`, `privateChats`)

### Network
- WebSocket for real-time communication (no polling)
- Message batching on backend
- Optimistic UI updates (show sent messages immediately)

## Testing Strategy

### Unit Tests (Future)
- `CryptoUtils`: Encryption/decryption correctness
- `ChatService`: API request/response handling
- `ViewModels`: Business logic validation

### Integration Tests (Future)
- WebSocket message flow
- Authentication flow
- Chat creation/joining

### UI Tests (Future)
- Login flow
- Send message
- Create/join chat
- Navigation between screens

## Build & Deployment

### Requirements
- Xcode 15.0+
- iOS 15.0+ deployment target
- Valid Apple Developer account (for push notifications)
- APNs key configured

### Configuration
1. Update `backend/env` with server URL
2. Add APNs key to `backend/apns-key.p8`
3. Configure `Info.plist` with APNs entitlements
4. Update `SHAiny.entitlements` for capabilities

### Build Configurations
- **Debug**: Development server, verbose logging
- **Release**: Production server, minimal logging

## Future Enhancements

### Features
- [ ] Group chat administration (kick, ban users)
- [ ] Message reactions (emoji)
- [ ] File/image sharing (encrypted)
- [ ] Voice messages
- [ ] Video calls
- [ ] Message search
- [ ] Chat export

### Architecture
- [ ] Core Data for offline message storage
- [ ] Background refresh for notifications
- [ ] Universal links for chat invitations
- [ ] Widget support (unread count)
- [ ] watchOS companion app
- [ ] macOS version (Catalyst or native)

### Security
- [ ] Signal Protocol integration
- [ ] Biometric authentication
- [ ] Self-destructing messages
- [ ] Screenshot detection
- [ ] Encrypted backups

## Contributing

### Code Style
- SwiftLint configuration enforced
- 4-space indentation
- Descriptive variable names
- Comments for complex logic
- Documentation comments for public APIs

### Git Workflow
- Feature branches from `main`
- Pull requests required
- Code review by at least one person
- All tests must pass

## License

See LICENSE file for details.

## Contact

For questions or support, contact the development team.

