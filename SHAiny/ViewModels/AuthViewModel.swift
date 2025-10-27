//
//  AuthViewModel.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation
import Combine

/// View model managing user authentication state and login/logout actions
final class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var errorMessage: String?
    
    private let keychainService = KeychainService.shared
    private let authService = AuthService.shared
    private let webSocketService = WebSocketService.shared
    private let notificationService = NotificationService.shared
    
    init() {
        checkAuthentication()
    }
    
    // Проверка авторизации при запуске
    func checkAuthentication() {
        authState = .loading
        
        if let token = keychainService.getAccessToken() {
            // Проверяем валидность токена
            Task {
                do {
                    let isValid = try await authService.verifyToken(token: token)
                    await MainActor.run {
                        if isValid {
                            self.authState = .authenticated
                            // Подключаемся к WebSocket после успешной аутентификации
                            self.webSocketService.connect()
                            // Запрашиваем разрешение на уведомления
                            self.notificationService.requestAuthorization()
                        } else {
                            self.authState = .unauthenticated
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.authState = .unauthenticated
                    }
                }
            }
        } else {
            authState = .unauthenticated
        }
    }
    
    // Логин по кодовой фразе
    func login(codePhrase: String) async {
        errorMessage = nil
        
        do {
            let response = try await authService.login(codePhrase: codePhrase)
            
                // Сохраняем токен в KeyChain
                _ = keychainService.saveAccessToken(response.accessToken)
                
                await MainActor.run {
                    authState = .authenticated
                    // Подключаемся к WebSocket после успешного логина
                    webSocketService.connect()
                    // Запрашиваем разрешение на уведомления
                    notificationService.requestAuthorization()
                }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // Logout
    func logout() {
        print("🚪 Logout: Deleting access token from Keychain")
        
        // Отключаемся от WebSocket
        webSocketService.disconnect()
        
        let deleted = keychainService.deleteAccessToken()
        print(deleted ? "✅ Access token deleted" : "⚠️ Failed to delete token")
        
        // Удаляем все ключи чатов
        ChatKeysStorage.shared.deleteAllKeys()
        
        // Удаляем все никнеймы
        ChatNicknamesStorage.shared.deleteAllNicknames()
        
        // Очищаем все уведомления
        notificationService.clearAllNotifications()
        
        authState = .unauthenticated
        print("🔄 Auth state changed to: unauthenticated")
    }
}

