//
//  resource_bundle.swift
//  
//
//  Created by Mohamed Afifi on 2023-06-28.
//

import Foundation

extension Bundle {
    private static let _fixedModule: Bundle = {
        Bundle.module
    }()
    
    @MainActor
    static var fixedModule: Bundle {
        _fixedModule
    }
}
