//
//  BadgeManager.swift
//  SHAiny
//
//  Centralized badge management service
//

import Foundation
import UIKit
import UserNotifications

/// Централизованный менеджер для управления app badge
class BadgeManager {
    static let shared = BadgeManager()
    
    private(set) var currentBadgeCount: Int = 0
    private let center = UNUserNotificationCenter.current()
    private var lastUpdateTime: Date = Date()
    
    private init() {
        // При инициализации синхронизируем с системным badge
        syncWithSystemBadge()
    }
    
    // MARK: - Public API
    
    /// Установить badge count
    /// - Parameter count: Новое значение badge
    func setBadge(_ count: Int) {
        let normalizedCount = max(0, count) // Не может быть отрицательным
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let oldValue = UIApplication.shared.applicationIconBadgeNumber
            UIApplication.shared.applicationIconBadgeNumber = normalizedCount
            self.currentBadgeCount = normalizedCount
            self.lastUpdateTime = Date()
            
            print("🔢 Badge updated: \(oldValue) → \(normalizedCount)")
            
            // Сохраняем timestamp этого обновления для проверки
            let updateTime = self.lastUpdateTime
            
            // Проверяем через небольшую задержку что значение не сбросилось
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self else { return }
                
                // Проверяем только если не было новых обновлений
                if self.lastUpdateTime == updateTime {
                    let actualBadge = UIApplication.shared.applicationIconBadgeNumber
                    
                    if actualBadge != normalizedCount {
                        print("⚠️ Badge mismatch detected! Expected: \(normalizedCount), actual: \(actualBadge). Restoring...")
                        UIApplication.shared.applicationIconBadgeNumber = normalizedCount
                    }
                }
            }
        }
    }
    
    /// Увеличить badge на указанное значение
    /// - Parameter increment: На сколько увеличить (по умолчанию 1)
    func incrementBadge(by increment: Int = 1) {
        setBadge(currentBadgeCount + increment)
    }
    
    /// Уменьшить badge на указанное значение
    /// - Parameter decrement: На сколько уменьшить (по умолчанию 1)
    func decrementBadge(by decrement: Int = 1) {
        setBadge(currentBadgeCount - decrement)
    }
    
    /// Сбросить badge в 0
    func clearBadge() {
        setBadge(0)
    }
    
    /// Синхронизировать с системным badge (при старте приложения)
    func syncWithSystemBadge() {
        DispatchQueue.main.async { [weak self] in
            let systemBadge = UIApplication.shared.applicationIconBadgeNumber
            self?.currentBadgeCount = systemBadge
            print("🔄 Badge synced with system: \(systemBadge)")
        }
    }
    
    /// Обновить badge на основе списка чатов
    /// - Parameter chats: Массив чатов с unreadCount
    func updateFromChats(_ chats: [Chat]) {
        let totalUnread = chats.reduce(0) { $0 + $1.unreadCount }
        setBadge(totalUnread)
    }
    
    /// Очистить все доставленные уведомления И сбросить badge
    func clearAllNotificationsAndBadge() {
        center.removeAllDeliveredNotifications()
        clearBadge()
        print("🧹 All notifications and badge cleared")
    }
    
    /// Очистить уведомления для конкретного чата
    /// - Parameters:
    ///   - chatId: ID чата
    ///   - completion: Callback с количеством удаленных уведомлений
    func clearNotifications(for chatId: String, completion: ((Int) -> Void)? = nil) {
        center.getDeliveredNotifications { [weak self] notifications in
            let identifiersToRemove = notifications
                .filter { notification in
                    if let notificationChatId = notification.request.content.userInfo["chatId"] as? String {
                        return notificationChatId == chatId
                    }
                    return false
                }
                .map { $0.request.identifier }
            
            if !identifiersToRemove.isEmpty {
                self?.center.removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
                print("🧹 Cleared \(identifiersToRemove.count) notification(s) for chat \(chatId)")
            }
            
            completion?(identifiersToRemove.count)
        }
    }
    
    /// Получить количество доставленных уведомлений
    /// - Parameter completion: Callback с количеством
    func getDeliveredNotificationsCount(completion: @escaping (Int) -> Void) {
        center.getDeliveredNotifications { notifications in
            completion(notifications.count)
        }
    }
    
    /// Получить количество уведомлений для конкретного чата
    /// - Parameters:
    ///   - chatId: ID чата
    ///   - completion: Callback с количеством
    func getNotificationsCount(for chatId: String, completion: @escaping (Int) -> Void) {
        center.getDeliveredNotifications { notifications in
            let count = notifications.filter { notification in
                if let notificationChatId = notification.request.content.userInfo["chatId"] as? String {
                    return notificationChatId == chatId
                }
                return false
            }.count
            completion(count)
        }
    }
}

