//
//  ProfileViewModel.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation
import Combine

final class ProfileViewModel: ObservableObject {
    @Published var showCreateInvite: Bool = false
    @Published var showSuccessAlert: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var generatedCode: String?
    
    private let authService = AuthService.shared
    private let keychainService = KeychainService.shared
    
    func generateInviteCode(_ codePhrase: String) async {
        guard !codePhrase.isEmpty else { return }
        
        errorMessage = nil
        isLoading = true
        
        do {
            let code = try await authService.generateCode(codePhrase: codePhrase)
            
            await MainActor.run {
                generatedCode = code
                isLoading = false
                showSuccessAlert = true
                print("✅ Invite code generated: \(code)")
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                print("❌ Failed to generate invite code: \(error.localizedDescription)")
            }
        }
    }
}

