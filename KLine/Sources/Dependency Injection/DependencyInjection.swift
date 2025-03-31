//
//  DependencyInjection.swift
//  KLine
//
//  Created by iya on 2025/3/28.
//

import Foundation

// MARK: - 生命周期管理
public enum DependencyScope {
    case transient   // 每次创建新实例
    case container    // 容器级单例
    case application  // 全局单例
}

// MARK: - 依赖解析协议
public protocol DependencyResolver {
    func resolve<Service>(_ type: Service.Type) -> Service
}

// MARK: - 依赖容器协议
public protocol DependencyContainer: DependencyResolver {
    func register<Service>(
        _ type: Service.Type,
        scope: DependencyScope,
        factory: @escaping (DependencyResolver) -> Service
    )
}

// MARK: - 容器实现
public final class DefaultDependencyContainer: DependencyContainer, DependencyResolver, @unchecked Sendable {
    private let syncQueue = DispatchQueue(label: "DIContainer.queue", attributes: .concurrent)
    private var registrations = [String: Registration]()
    private var applicationInstances = [String: Any]()
    private var containerInstances = [String: Any]()
    
    public init() {}
    
    public func register<Service>(
        _ type: Service.Type,
        scope: DependencyScope = .transient,
        factory: @escaping (DependencyResolver) -> Service
    ) {
        let key = String(describing: type)
        let registration = Registration(scope: scope, factory: factory)
        
        syncQueue.async(flags: .barrier) { [unowned self] in
            self.registrations[key] = registration
        }
    }
    
    public func resolve<Service>(_ type: Service.Type) -> Service {
        let key = String(describing: type)
        
        return syncQueue.sync {
            guard let registration = registrations[key] else {
                fatalError("No registration found for \(key)")
            }
            
            switch registration.scope {
            case .transient:
                return registration.factory(self) as! Service
                
            case .container:
                if let instance = containerInstances[key] {
                    return instance as! Service
                }
                let instance = registration.factory(self)
                containerInstances[key] = instance
                return instance as! Service
                
            case .application:
                if let instance = applicationInstances[key] {
                    return instance as! Service
                }
                let instance = registration.factory(self)
                applicationInstances[key] = instance
                return instance as! Service
            }
        }
    }
    
    private struct Registration : @unchecked Sendable{
        let scope: DependencyScope
        let factory: (DependencyResolver) -> Any
    }
}

// MARK: - DSL 支持
public struct DependencyRegistration {
    let type: Any.Type
    let scope: DependencyScope
    let factory: (DependencyResolver) -> Any
}

@resultBuilder
public struct ContainerBuilder {
    public static func buildBlock(_ components: DependencyRegistration...) -> [DependencyRegistration] {
        components
    }
}

// MARK: - 容器入口
public enum Container {
    nonisolated(unsafe) public static let shared: DependencyResolver = DefaultDependencyContainer()
    
    public static func build(@ContainerBuilder _ builder: () -> [DependencyRegistration]) -> DependencyContainer {
        let container = DefaultDependencyContainer()
        builder().forEach { registration in
            container.register(registration.type as! (any Any).Type, scope: registration.scope, factory: registration.factory)
        }
        return container
    }
}

public func register<Service>(
    _ type: Service.Type,
    scope: DependencyScope = .transient,
    factory: @escaping (DependencyResolver) -> Service
) -> DependencyRegistration {
    DependencyRegistration(type: type, scope: scope) { factory($0) }
}
