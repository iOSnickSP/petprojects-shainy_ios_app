//
//  AuthState.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Foundation

/// Represents the current authentication state of the user
enum AuthState {
    /// Initial state while checking authentication token validity
    case loading
    
    /// User is authenticated and can access the app
    case authenticated
    
    /// User needs to log in with a code phrase
    case unauthenticated
}

