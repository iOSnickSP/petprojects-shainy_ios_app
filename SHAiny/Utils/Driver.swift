//
//  Driver.swift
//  SHAiny
//
//  Created by Сергей Вихляев on 26.10.2025.
//

import Combine
import Foundation

@propertyWrapper
struct Driver<Value> {
    private let subject: CurrentValueSubject<Value, Never>
    
    init(wrappedValue: Value) {
        subject = CurrentValueSubject(wrappedValue)
    }
    
    var wrappedValue: Value {
        get { subject.value }
        set { subject.send(newValue) }
    }
    
    var projectedValue: AnyPublisher<Value, Never> {
        subject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

