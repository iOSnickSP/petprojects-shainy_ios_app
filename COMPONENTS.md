# SHAiny Components Reference

Quick reference guide for all major components in the iOS application.

## Models

### Chat (`Models/Chat.swift`)
Represents a chat room (global announcement or private encrypted).

**Key Properties**:
- `chatId`: Backend identifier
- `name`: Display name (decrypted if has custom name)
- `encryptionKey`: Stored locally for message encryption/decryption
- `unreadCount`: Number of unread messages
- `isGlobal`: Whether this is the announcements channel
- `isReadOnly`: Whether users can send messages

**Usage**:
```swift
let chat = Chat(
    chatId: "abc123",
    name: "My Secret Chat",
    lastMessage: "Hello!",
    timestamp: Date(),
    participantsCount: 5,
    encryptionKey: "myKeyPhrase"
)
```

### Message (`Models/Message.swift`)
Represents a single message in a chat.

**Key Properties**:
- `text`: Decrypted message text (displayed to user)
- `encryptedText`: Original encrypted text (for verification/debug mode)
- `shaHash`: SHA-256 hash of original plaintext (for integrity check)
- `isFromCurrentUser`: Determines message bubble alignment
- `senderName`: Nickname of sender in this chat

**Integrity Check**:
```swift
let calculatedHash = CryptoUtils.generateHash(decryptedText)
let isValid = (calculatedHash == message.shaHash)
```

### AuthState (`Models/AuthState.swift`)
Represents authentication state throughout the app.

**States**:
- `.loading`: Verifying stored token
- `.authenticated`: User has valid token, show main app
- `.unauthenticated`: Show login screen

### ChatConnectionState (`Models/ChatConnectionState.swift`)
Represents state when connecting to/creating a chat.

**States**:
- `.checking`: Verifying if chat with key phrase exists
- `.exists(chatId, chatName)`: Chat found, show "Join" button
- `.notExists`: Show "Create" button
- `.error(message)`: Display error message

## ViewModels

### AuthViewModel (`ViewModels/AuthViewModel.swift`)
Manages authentication state and user login/logout.

**Key Methods**:
- `checkAuthentication()`: Called on app launch, validates stored token
- `login(codePhrase:)`: Authenticate user with code phrase
- `logout()`: Clear credentials and disconnect WebSocket

**Shared Instance**: Injected as `@EnvironmentObject` app-wide

**Usage in Views**:
```swift
@EnvironmentObject var authViewModel: AuthViewModel

if authViewModel.authState == .authenticated {
    ContentView()
}
```

### ChatListViewModel (`ViewModels/ChatListViewModel.swift`)
Manages the list of chats on the main screen.

**Key Properties**:
- `chats`: All chats (global + private)
- `globalChats`: Filtered announcements
- `privateChats`: Filtered private chats
- `isLoading`: Show loading indicator
- `errorMessage`: Error to display

**Key Methods**:
- `loadChats(preserveIds:)`: Fetch chats from backend
- `markChatAsRead(chatId:)`: Clear unread count
- `checkAndConnect(keyPhrase:)`: Check if chat exists
- `createChat(keyPhrase:)`: Create new chat
- `joinChat(chatId:keyPhrase:)`: Join existing chat

**UUID Preservation**:
When `preserveIds: true`, existing chat UUIDs are preserved during reload to prevent navigation issues.

### ChatViewModel (`ViewModels/ChatViewModel.swift`)
Manages a single chat conversation.

**Key Properties**:
- `messages`: Array of messages (paginated)
- `messageText`: Current text input value
- `participantsCount`: Number of chat members
- `canSendMessages`: Whether user can send (false for read-only channels)

**Key Methods**:
- `sendMessage()`: Encrypt and send message via WebSocket
- `renameChat(newName:)`: Set encrypted custom chat name
- `setNickname(_:)`: Set user's nickname for this chat

**Pending Messages**:
If user hasn't set nickname, message is held in `pendingMessageText` until nickname is provided.

## Services

### AuthService (`Services/AuthService.swift`)
Handles authentication API calls.

**Endpoints**:
- `login(codePhrase:)` → Access token + user ID
- `verifyToken(token:)` → Boolean validity check
- `generateCode(codePhrase:)` → New invite code for sharing

**Singleton**: `AuthService.shared`

### ChatService (`Services/ChatService.swift`)
Handles all chat-related API calls.

**Key Methods**:
- `fetchChats()` → List of user's chats
- `fetchMessages(chatId:encryptionKey:limit:offset:)` → Paginated messages
- `checkChatExists(keyHash:)` → Check if chat exists
- `createChat(keyPhrase:keyHash:)` → Create new chat
- `joinChat(chatId:keyPhrase:)` → Join existing chat
- `renameChat(chatId:newName:encryptionKey:)` → Set encrypted name
- `markChatAsRead(chatId:)` → Clear unread count on backend
- `setNickname(_:for:)` → Set user nickname in chat
- `getNickname(for:)` → Get user nickname in chat

**Singleton**: `ChatService.shared`

**Automatic Decryption**:
`fetchChats()` and `fetchMessages()` automatically decrypt names and messages using stored keys.

### WebSocketService (`Services/WebSocketService.swift`)
Manages WebSocket connection for real-time messaging.

**Publishers**:
- `newMessagePublisher`: Emits `(chatId, message)` tuples
- `chatsUpdatedPublisher`: Signals to reload chat list
- `isConnected`: Boolean connection state

**Key Methods**:
- `connect()`: Establish WebSocket connection
- `authenticate()`: Send auth token to server
- `sendChatMessage(chatId:encryptedText:shaHash:)`: Send message
- `disconnect()`: Close connection

**Singleton**: `WebSocketService.shared`

**Lifecycle**:
- Connected after successful authentication
- Disconnected on logout or app termination

### NotificationService (`Services/NotificationService.swift`)
Manages push notifications (APNs).

**Key Methods**:
- `requestAuthorization()`: Ask user for notification permissions
- `registerDeviceToken(token:)`: Send device token to backend
- `showNewMessageNotification()`: Display local notification
- `clearNotifications(for:)`: Clear notifications for specific chat
- `clearAllNotifications()`: Clear all notifications

**Singleton**: `NotificationService.shared`

**Current Open Chat**:
Property `currentOpenChatId` prevents notifications for currently open chat.

### KeychainService (`Services/KeychainService.swift`)
Secure storage for access tokens.

**Key Methods**:
- `saveAccessToken(_:)`: Store token in Keychain
- `getAccessToken()` → Retrieve token
- `deleteAccessToken()`: Remove token
- `getUserIdFromToken()`: Extract user ID from JWT

**Singleton**: `KeychainService.shared`

**Why Keychain?**
Tokens are cryptographically secured and persist across app reinstalls.

### SettingsService (`Services/SettingsService.swift`)
Manages app settings stored in UserDefaults.

**Settings**:
- `serverURL`: Backend API base URL
- `webSocketURL`: WebSocket server URL
- `showEncryptedData`: Display encrypted text and hashes in messages

**Singleton**: `SettingsService.shared`

### ChatKeysStorage (`Services/ChatKeysStorage.swift`)
**Securely stores encryption keys for chats in iOS Keychain.**

**Key Methods**:
- `saveKey(_:forChatId:)`: Store encryption key in Keychain
- `getKey(forChatId:)` → Retrieve key from Keychain
- `deleteKey(forChatId:)`: Remove key from Keychain
- `deleteAllKeys()`: Clear all keys (on logout)

**Singleton**: `ChatKeysStorage.shared`

**Security**:
- ✅ **Keychain Storage**: Keys encrypted by iOS system
- ✅ **Protected by Device Lock**: Accessible only after device unlock
- ✅ **Automatic Migration**: Old UserDefaults keys migrated on first launch
- Format: Each key stored as `chatKey_<chatId>` in service `com.shainy.app.chatkeys`

**Why Keychain?**
Previously stored in UserDefaults (insecure). Now uses Keychain for proper encryption and protection.

### ChatNicknamesStorage (`Services/ChatNicknamesStorage.swift`)
Stores user nicknames per chat in UserDefaults.

**Key Methods**:
- `saveNickname(_:for:)`: Store nickname for chat
- `getNickname(for:)` → Retrieve nickname
- `deleteNickname(for:)`: Remove nickname
- `deleteAllNicknames()`: Clear all nicknames (on logout)

**Singleton**: `ChatNicknamesStorage.shared`

## Views

### ContentView (`Views/ContentView.swift`)
Main screen displaying chat list.

**Features**:
- Pull-to-refresh
- Separate sections for global and private chats
- Unread badges
- Navigation to chat detail
- Push notification deep linking

**Navigation States**:
- Loading: Shows progress indicator
- Error: Shows error message with retry button
- Empty: Shows "No chats yet" message
- Loaded: Shows chat list

### ChatView (`Views/ChatView.swift`)
Individual chat conversation screen.

**Features**:
- Real-time message updates
- Automatic scroll to bottom
- Keyboard avoidance
- Send message input
- Nickname dialog (first message)
- Chat info sheet
- Read-only mode for announcements

**Keyboard Handling**:
Observes `keyboardWillShow/Hide` notifications to adjust content inset.

### ChatConnectionView (`Views/ChatConnectionView.swift`)
Modal for joining or creating a chat.

**Flow**:
1. User enters key phrase
2. System checks if chat exists
3. If exists: show "Join" button
4. If not exists: show "Create" button
5. After join/create: optional naming dialog

**States**: Mirrors `ChatConnectionState` enum

### ChatInfoView (`Views/ChatInfoView.swift`)
Chat details and settings sheet.

**Features**:
- Participant count
- Chat key phrase display (with copy)
- Share key phrase (generate invite code)
- Rename chat
- Leave chat

**Security Note**: Key phrase is displayed here for sharing purposes.

### LoginView (`Views/LoginView.swift`)
Authentication screen.

**Features**:
- Code phrase input
- Login button
- Error message display
- Loading state

**UX**: Disables input during login to prevent duplicate requests.

### ProfileView (`Views/ProfileView.swift`)
User profile and app settings.

**Features**:
- Server URL configuration
- Display settings toggle
- Logout button
- App version info

### DisplaySettingsView (`Views/DisplaySettingsView.swift`)
Toggle for showing encrypted data in messages.

**Setting**: `showEncryptedData`
- When ON: Messages show encrypted text, SHA hash, and decrypted text
- When OFF: Only decrypted text shown

### SplashView (`Views/SplashView.swift`)
Loading screen shown during authentication check.

**Simple View**: Just app logo and loading indicator.

## UI Components

### ChatRowView (`Views/Components/ChatRowView.swift`)
Individual chat row in list.

**Design Variants**:
- Global chats: Megaphone icon, orange/red unread badge
- Private chats: Lock icon, purple/blue unread badge

**Displays**:
- Chat name
- Participant count / last message sender
- Unread badge

### MessageBubbleView (`Views/Components/MessageBubbleView.swift`)
Individual message bubble in chat.

**Features**:
- Sender name (for messages from others)
- Optional encrypted data section (expandable)
- Decrypted message text
- Timestamp
- Color-coded by sender (purple/blue gradient for current user)

**Alignment**:
- Current user messages: right-aligned
- Other user messages: left-aligned

### ExpandableSHAView (`Views/Components/ExpandableSHAView.swift`)
Expandable view for encrypted text or SHA hash.

**States**:
- Collapsed: Shows truncated text (30 chars) + expand button
- Expanded: Shows full text + copy button + collapse button

**Usage in `MessageBubbleView`** when `showEncryptedData` is ON.

### EmptyPrivateChatsView (`Views/Components/EmptyPrivateChatsView.swift`)
Informational card shown when user has no private chats.

**Content**:
- Icon and title
- Explanation text
- Call-to-action hint

## Utils

### CryptoUtils (`Utils/CryptoUtils.swift`)
Cryptographic functions for encryption, decryption, and hashing.

**Methods**:
- `encrypt(_:keyPhrase:)`: AES-256-CBC encryption with random IV
- `decrypt(_:keyPhrase:)`: AES-256-CBC decryption
- `generateHash(_:)`: SHA-256 hash generation
- `deriveKey(from:)`: PBKDF2 key derivation from phrase

**IV Handling**:
IV is prepended to ciphertext as `iv:ciphertext` format.

**Algorithm**: AES-256-CBC with PKCS7 padding

### Driver (`Utils/Driver.swift`)
Property wrapper for Combine `CurrentValueSubject` with main thread delivery.

**Usage in ViewModels**:
```swift
@Driver var messages: [Message] = []

// Automatically publishes changes on main thread
self.messages.append(newMessage)
```

**Why?**
- Ensures UI updates always happen on main thread
- Simplifies reactive bindings in ViewModels
- Alternative to manual `MainActor.run { }` blocks

## Entry Point

### SHAinyApp (`SHAinyApp.swift`)
App entry point and root view.

**Structure**:
- Creates `AuthViewModel` as `@StateObject`
- Routes based on `authState`:
  - `.loading` → `SplashView`
  - `.authenticated` → `ContentView`
  - `.unauthenticated` → `LoginView`
- Injects `AuthViewModel` as `@EnvironmentObject`
- Registers `AppDelegate` for APNs callbacks

**AppDelegate**:
- Requests notification authorization
- Handles device token registration
- Handles registration errors

## Common Patterns

### Service Singletons
All services use shared singleton pattern:
```swift
class MyService {
    static let shared = MyService()
    private init() { }
}
```

### Async/Await in ViewModels
```swift
func loadData() {
    Task {
        do {
            let data = try await service.fetchData()
            await MainActor.run {
                self.data = data
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }
}
```

### Combine Subscriptions
```swift
webSocketService.newMessagePublisher
    .sink { [weak self] (chatId, message) in
        // Handle message
    }
    .store(in: &cancellables)
```

### SwiftUI Navigation
```swift
NavigationView {
    List {
        NavigationLink(destination: DetailView()) {
            RowView()
        }
    }
}
```

## Debugging Tips

### Enable Encrypted Data Display
Profile → Display Settings → Show Encrypted Data

This shows:
- Original encrypted text
- SHA-256 hash
- Decrypted text

Use to debug encryption/decryption issues.

### Console Logging
All services print detailed logs with emojis:
- 🔐 Authentication
- 💬 Chat operations
- 📤📩 Message sending/receiving
- ✅ Success
- ❌ Errors

### Common Issues

**"Chat key not found"**:
- Encryption key missing from `ChatKeysStorage`
- Solution: Rejoin chat with correct key phrase

**"Failed to decrypt message"**:
- Wrong encryption key used
- Message corrupted during transmission
- Check SHA hash mismatch in logs

**"WebSocket not connected"**:
- Token expired or invalid
- Network connection issue
- Check authentication state

**"Nickname required"**:
- First message in chat requires nickname
- Dialog should appear automatically
- Check `ChatViewModel.shouldShowNicknameDialog`

## Testing Checklist

### Manual Testing
- [ ] Login with valid code phrase
- [ ] Login with invalid code phrase (should fail)
- [ ] Create new chat
- [ ] Join existing chat
- [ ] Send message
- [ ] Receive message in real-time
- [ ] Rename chat
- [ ] Set nickname
- [ ] Navigate from push notification
- [ ] Pull-to-refresh chat list
- [ ] Logout

### Edge Cases
- [ ] Send message before setting nickname
- [ ] Join chat with wrong key phrase
- [ ] Network disconnection during message send
- [ ] App backgrounded during chat
- [ ] Multiple devices logged in

## Performance Monitoring

### Memory
- Message lists use `LazyVStack` to avoid loading all views
- Pagination limits messages loaded at once
- WebSocket cleanup on view disappear

### Network
- WebSocket preferred over HTTP polling
- Message batching reduces requests
- Cached chat list with pull-to-refresh

### UI Responsiveness
- All network calls async with `Task`
- Main thread updates via `MainActor.run`
- Loading states prevent UI freezing

