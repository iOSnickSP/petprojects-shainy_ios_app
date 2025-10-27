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
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Запрашиваем разрешение на уведомления при старте
        NotificationService.shared.requestAuthorization()
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
}
