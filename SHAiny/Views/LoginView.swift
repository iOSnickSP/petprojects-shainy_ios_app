//
//  LoginView.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var codePhrase: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.12)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isInputFocused = false
                    }
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Верхний отступ
                        Spacer()
                            .frame(height: geometry.size.height * 0.15)
                        
                        // Logo
                        VStack(spacing: 16) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("SHAiny")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Enter code phrase to join")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.bottom, 60)
                        
                        // Input field
                        VStack(spacing: 16) {
                            TextField("Code phrase", text: $codePhrase)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color(red: 0.15, green: 0.15, blue: 0.17))
                                .cornerRadius(12)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isInputFocused)
                                .disabled(isLoading)
                                .submitLabel(.done)
                                .onSubmit {
                                    if !codePhrase.isEmpty && !isLoading {
                                        handleLogin()
                                    }
                                }
                            
                            if let errorMessage = authViewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Button(action: {
                                handleLogin()
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Enter")
                                            .font(.headline)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    LinearGradient(
                                        colors: codePhrase.isEmpty ? [.gray, .gray] : [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            .disabled(codePhrase.isEmpty || isLoading)
                        }
                        .padding(.horizontal, 32)
                        
                        // Info text
                        Text("You need a code phrase from an existing user to join SHAiny")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 40)
                        
                        Spacer()
                            .frame(height: 60)
                    }
                    .frame(minHeight: geometry.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func handleLogin() {
        isInputFocused = false
        isLoading = true
        
        Task {
            await authViewModel.login(codePhrase: codePhrase)
            await MainActor.run {
                isLoading = false
                if authViewModel.authState != .authenticated {
                    codePhrase = ""
                }
            }
        }
    }
}

#Preview {
    LoginView(authViewModel: AuthViewModel())
}

