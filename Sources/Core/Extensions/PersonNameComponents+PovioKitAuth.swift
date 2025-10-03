//
//  PersonNameComponents+PovioKitAuth.swift
//  PovioKitAuth
//
//  Created by Egzon Arifi on 09/11/2024.
//  Copyright © 2025 Povio Inc. All rights reserved.
//

import AuthenticationServices
import Foundation

public extension PersonNameComponents {
  var name: String? {
    guard let givenName else {
      return familyName
    }
    guard let familyName else {
      return givenName
    }
    return "\(givenName) \(familyName)"
  }
}

public extension PersonNameComponents {
  init(
    namePrefix: String? = .none,
    middleName: String? = .none,
    givenName: String? = .none,
    familyName: String? = .none,
    nameSuffix: String? = .none,
    nickname: String? = .none,
    phoneticRepresentation: PersonNameComponents? = .none
  ) {
    self.init()
    self.namePrefix = namePrefix
    self.familyName = familyName
    self.middleName = middleName
    self.givenName = givenName
    self.nameSuffix = nameSuffix
    self.nickname = nickname
    self.phoneticRepresentation = phoneticRepresentation
  }
}
