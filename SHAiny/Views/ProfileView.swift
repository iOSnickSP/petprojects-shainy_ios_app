//
//  ProfileView.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showWarning = false
    @State private var showLogoutAlert = false
    
    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.12)
                .ignoresSafeArea()
            
            List {
                Section {
                    Button(action: {
                        showWarning = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Invite New User")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Generate access code")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.17))
                } header: {
                    Text("Access Management")
                        .foregroundColor(.gray)
                }
                
                Section {
                    NavigationLink(destination: DisplaySettingsView()) {
                        HStack {
                            Image(systemName: "eye.circle")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Display Settings")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Customize message appearance")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.17))
                } header: {
                    Text("Preferences")
                        .foregroundColor(.gray)
                }
                
                #if DEBUG
                Section {
                    Button(action: {
                        showLogoutAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .font(.title2)
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Logout (Debug)")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                
                                Text("Delete access token")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.17))
                } header: {
                    Text("Debug Tools")
                        .foregroundColor(.gray)
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showWarning) {
            WarningView(
                onAccept: {
                    showWarning = false
                    viewModel.showCreateInvite = true
                },
                onCancel: {
                    showWarning = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showCreateInvite) {
            CreateInviteView(viewModel: viewModel)
        }
        .alert("Success", isPresented: $viewModel.showSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This code phrase will be valid for only 30 minutes, after which it will no longer be valid.")
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
                authViewModel.logout()
            }
        } message: {
            Text("Delete access token and return to login screen?")
        }
    }
}

struct WarningView: View {
    let onAccept: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.12)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Warning icon
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.orange)
                            .padding(.top, 40)
                        
                        VStack(spacing: 16) {
                            Text("Security Warning")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("SHAiny provides a highly secure communication method. Please think carefully before granting access to new users.")
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                WarningPoint(text: "New users will have permanent access to the service")
                                WarningPoint(text: "After 3 months, they can invite other users")
                                WarningPoint(text: "You are responsible for those you invite")
                            }
                            .padding(.horizontal, 32)
                            .padding(.top, 16)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 12) {
                            Button(action: onAccept) {
                                Text("I Understand All Risks")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: onCancel) {
                                Text("Cancel")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(red: 0.15, green: 0.15, blue: 0.17))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Warning")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
    }
}

struct WarningPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.orange)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct CreateInviteView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    @State private var codePhrase = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dangerous red background
                LinearGradient(
                    colors: [
                        Color(red: 0.3, green: 0.0, blue: 0.0),
                        Color(red: 0.1, green: 0.0, blue: 0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Skull icon
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.red)
                            .padding(.top, 40)
                        
                        VStack(spacing: 16) {
                            Text("Create Access Code")
                                .font(.title.bold())
                                .foregroundColor(.white)
                            
                            Text("This code will grant permanent access to SHAiny. Choose a unique phrase that only you and the new user will know.")
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        VStack(spacing: 16) {
                            TextField("Enter code phrase", text: $codePhrase)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(12)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isInputFocused)
                                .disabled(viewModel.isLoading)
                            
                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    await viewModel.generateInviteCode(codePhrase)
                                    if viewModel.generatedCode != nil {
                                        dismiss()
                                    }
                                }
                            }) {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Confirm Code Phrase")
                                            .font(.headline)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    codePhrase.isEmpty ? Color.gray : Color.red
                                )
                                .cornerRadius(12)
                            }
                            .disabled(codePhrase.isEmpty || viewModel.isLoading)
                            
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Cancel")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("⚠️ Danger Zone")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(AuthViewModel())
    }
}

