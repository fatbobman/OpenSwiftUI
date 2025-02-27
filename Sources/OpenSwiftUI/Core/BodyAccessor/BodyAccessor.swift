//
//  BodyAccessor.swift
//  OpenSwiftUI
//
//  Audited for RELEASE_2021
//  Status: Complete

internal import OpenGraphShims

protocol BodyAccessor<Container, Body> {
    associatedtype Container
    associatedtype Body
    func updateBody(of: Container, changed: Bool)
}

extension BodyAccessor {
    func setBody(_ body: () -> Body) {
        let value = traceRuleBody(Container.self) {
            OGGraph.withoutUpdate(body)
        }
        withUnsafePointer(to: value) { value in
            OGGraph.setOutputValue(value)
        }
    }
}
