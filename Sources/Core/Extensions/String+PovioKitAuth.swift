//
//  String+PovioKitAuth.swift
//  PovioKitAuth
//
//  Created by Borut Tomazin on 10.12.2025.
//

import Foundation
import CryptoKit

public extension String {
	var sha256: String {
		SHA256
			.hash(data: Data(utf8))
			.compactMap { String(format: "%02x", $0) }
			.joined()
	}
}
