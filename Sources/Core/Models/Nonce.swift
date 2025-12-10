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
