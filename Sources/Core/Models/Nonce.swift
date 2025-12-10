//
//  Nonce.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 10/12/2025.
//  Copyright © 2025 Povio Inc. All rights reserved.
//

import Foundation

public enum Nonce {
	case random(length: UInt)
	case custom(value: String)
}

public extension Nonce {
	var value: String {
		switch self {
		case .random(let length):
			return generateNonceString(length: length).sha256
		case .custom(let value):
			return value.sha256
		}
	}
}

private extension Nonce {
	func generateNonceString(length: UInt = 32) -> String {
		guard length > 0 else { return "zero-length-nonce" }
		let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
		let result = (0..<length).compactMap { _ in charset.randomElement() }
		guard result.count == length else { fatalError("Unable to generate nonce!") }
		return String(result)
	}
}
