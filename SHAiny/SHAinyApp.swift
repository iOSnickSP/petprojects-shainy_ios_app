//
//  SHAinyApp.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import SwiftUI

@main
struct SHAinyApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch authViewModel.authState {
                case .loading:
                    SplashView()
                case .authenticated:
                    ContentView()
                case .unauthenticated:
                    LoginView(authViewModel: authViewModel)
                }
            }
            .environmentObject(authViewModel)
        }
    }
}

// AppDelegate для обработки APNs callbacks
class AppDelegate: NSObject, UIApplicationDelegate {
    private let badgeManager = BadgeManager.shared
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Синхронизируем badge при запуске
        badgeManager.syncWithSystemBadge()
        
        // Запрашиваем разрешение на уведомления при старте
        NotificationService.shared.requestAuthorization()
        
        // Обрабатываем launch из notification
        if let userInfo = launchOptions?[.remoteNotification] as? [String: Any] {
            handleRemoteNotification(userInfo: userInfo)
        }
        
        return true
    }
    
    // Успешная регистрация device token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        NotificationService.shared.didRegisterForRemoteNotifications(with: deviceToken)
    }
    
    // Ошибка регистрации
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationService.shared.didFailToRegisterForRemoteNotifications(with: error)
    }
    
    // Обработка remote notification когда приложение в фоне или закрыто
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("📱 Remote notification received")
        
        // Обрабатываем badge из aps payload
        if let aps = userInfo["aps"] as? [String: Any],
           let badge = aps["badge"] as? Int {
            badgeManager.setBadge(badge)
            print("🔢 Badge updated from remote notification: \(badge)")
        }
        
        handleRemoteNotification(userInfo: userInfo)
        completionHandler(.newData)
    }
    
    // Обработка содержимого notification
    private func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        // Извлекаем chatId если есть
        if let chatId = userInfo["chatId"] as? String {
            print("📱 Notification for chat: \(chatId)")
            
            // Отправляем событие для навигации
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToChat"),
                object: nil,
                userInfo: ["chatId": chatId]
            )
        }
    }
    
    // Обработка изменения состояния приложения
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Синхронизируем badge при активации
        badgeManager.syncWithSystemBadge()
        print("📱 App became active, badge synced")
    }
}
