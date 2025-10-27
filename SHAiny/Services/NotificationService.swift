//
//  NotificationService.swift
//  SHAiny
//
//  Created by AI Assistant on 26.10.2025.
//

import Foundation
import UserNotifications
import Combine
import UIKit

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var currentOpenChatId: String? = nil
    @Published var deviceToken: String? = nil
    private let center = UNUserNotificationCenter.current()
    
    private var baseURL: String {
        return SettingsService.shared.serverURL
    }
    
    private override init() {
        super.init()
        center.delegate = self
    }
    
    // Запрос разрешения на уведомления + регистрация для remote notifications
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if granted {
                print("✅ Notification permission granted")
                // Регистрируем для remote notifications
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            } else {
                print("⚠️ Notification permission denied")
            }
        }
    }
    
    // Обработка успешной регистрации device token
    func didRegisterForRemoteNotifications(with deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        print("📱 Device token: \(tokenString)")
        
        // Отправляем токен на сервер
        Task {
            await sendDeviceTokenToServer(tokenString)
        }
    }
    
    // Обработка ошибки регистрации
    func didFailToRegisterForRemoteNotifications(with error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // Отправка device token на сервер
    private func sendDeviceTokenToServer(_ token: String) async {
        guard let authToken = KeychainService.shared.getAccessToken(),
              let url = URL(string: "\(baseURL)/notifications/register") else {
            print("❌ Cannot send device token - missing auth token or server URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["deviceToken": self.deviceToken ?? ""]
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("✅ Device token registered on server")
            } else {
                print("⚠️ Failed to register device token: \(String(data: data, encoding: .utf8) ?? "unknown")")
            }
        } catch {
            print("❌ Error sending device token: \(error.localizedDescription)")
        }
    }
    
    // Проверка статуса разрешений
    func checkAuthorizationStatus(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            completion(settings.authorizationStatus == .authorized)
        }
    }
    
    // Показать локальное уведомление о новом сообщении
    func showNewMessageNotification(chatName: String, messageText: String, chatId: String, senderName: String?) {
        // Не показываем уведомление, если пользователь в этом чате
        if currentOpenChatId == chatId {
            print("🔕 Skipping notification - user is in the chat")
            return
        }
        
        checkAuthorizationStatus { [weak self] authorized in
            guard authorized else {
                print("⚠️ Notifications not authorized")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = chatName
            
            if let sender = senderName {
                content.subtitle = "\(sender) left a message"
            }
            
            content.body = messageText
            content.sound = .default
            // Badge будет обновлен автоматически через updateBadgeCount
            
            // Добавляем chatId в userInfo для навигации
            content.userInfo = ["chatId": chatId]
            
            // Создаем запрос на уведомление (немедленно)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // nil = показать немедленно
            )
            
            self?.center.add(request) { error in
                if let error = error {
                    print("❌ Failed to show notification: \(error.localizedDescription)")
                } else {
                    print("✅ Notification shown for chat: \(chatName)")
                }
            }
        }
    }
    
    // Очистить все уведомления
    func clearAllNotifications() {
        center.removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    // Очистить уведомления для конкретного чата
    func clearNotifications(for chatId: String) {
        center.getDeliveredNotifications { notifications in
            let identifiersToRemove = notifications
                .filter { notification in
                    if let notificationChatId = notification.request.content.userInfo["chatId"] as? String {
                        return notificationChatId == chatId
                    }
                    return false
                }
                .map { $0.request.identifier }
            
            self.center.removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
            print("🧹 Cleared \(identifiersToRemove.count) notifications for chat \(chatId)")
        }
    }
    
    // Обновить badge count на основе общего количества непрочитанных сообщений
    func updateBadgeCount(totalUnread: Int) {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = totalUnread
            print("🔢 Badge updated: \(totalUnread)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    // Показывать уведомления даже когда приложение на переднем плане
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // В iOS 14+ используем .banner и .sound
        completionHandler([.banner, .sound, .badge])
    }
    
    // Обработка нажатия на уведомление
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let chatId = userInfo["chatId"] as? String {
            print("📱 User tapped notification for chat: \(chatId)")
            
            // Отправляем событие для навигации
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToChat"),
                object: nil,
                userInfo: ["chatId": chatId]
            )
        }
        
        completionHandler()
    }
}

