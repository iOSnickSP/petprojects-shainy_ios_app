//
//  AuthService.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation

class AuthService {
    static let shared = AuthService()
    
    private var baseURL: String {
        return SettingsService.shared.serverURL
    }
    
    private init() {
        print("🌐 AuthService initialized")
    }
    
    struct LoginResponse: Codable {
        let accessToken: String
        let userId: String
    }
    
    struct ErrorResponse: Codable {
        let error: String
    }
    
    struct GenerateCodeResponse: Codable {
        let codePhrase: String
    }
    
    // Логин по кодовой фразе
    func login(codePhrase: String) async throws -> LoginResponse {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["codePhrase": codePhrase]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("🔐 Attempting login with code phrase...")
        print("📡 Request URL: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            print("📊 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                print("✅ Login successful! UserId: \(loginResponse.userId)")
                return loginResponse
            } else {
                let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                let errorMessage = errorResponse?.error ?? "Login failed"
                print("❌ Login failed: \(errorMessage)")
                throw NSError(domain: "AuthService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Проверка токена
    func verifyToken(token: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/auth/verify")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🔍 Verifying token...")
        print("📡 Request URL: \(url.absoluteString)")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                return false
            }
            
            print("📊 Verify response status: \(httpResponse.statusCode)")
            let isValid = httpResponse.statusCode == 200
            print(isValid ? "✅ Token is valid" : "❌ Token is invalid")
            
            return isValid
        } catch {
            print("❌ Token verification error: \(error.localizedDescription)")
            return false
        }
    }
    
    // Генерация кодовой фразы для нового пользователя
    func generateCode(codePhrase: String) async throws -> String {
        guard let token = KeychainService.shared.getAccessToken() else {
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
        }
        
        let url = URL(string: "\(baseURL)/auth/generate-code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = ["codePhrase": codePhrase]
        request.httpBody = try JSONEncoder().encode(body)
        
        print("🔑 Generating invite code...")
        print("📡 Request URL: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            print("📊 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let generateResponse = try JSONDecoder().decode(GenerateCodeResponse.self, from: data)
                print("✅ Code generated successfully")
                return generateResponse.codePhrase
            } else {
                let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                let errorMessage = errorResponse?.error ?? "Failed to generate code"
                print("❌ Generate code failed: \(errorMessage)")
                throw NSError(domain: "AuthService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            throw error
        }
    }
}

