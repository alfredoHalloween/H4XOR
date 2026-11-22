//
//  SmokeTests.swift
//  H4XORTests
//

import Testing
@testable import H4XOR

/// Test mínimo para comprobar que el target de tests compila, se enlaza con la app y corre.
struct SmokeTests {

    @Test func appModuleIsReachable() {
        #expect(HTTPMethod.get.rawValue == "GET")
    }
}
