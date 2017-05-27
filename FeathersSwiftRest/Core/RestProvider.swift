//
//  RestProvider.swift
//  FeathersSwiftRest
//
//  Created by Brendan Conron on 5/16/17.
//  Copyright © 2017 FeathersJS. All rights reserved.
//

import Foundation
import Alamofire
import enum Result.Result
import enum Result.NoError
import Feathers
import ReactiveSwift

final public class RestProvider: Provider {

    public var supportsRealtimeEvents: Bool {
        return false
    }

    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public final func setup(app: Feathers) {}

    public func request(endpoint: Endpoint) -> SignalProducer<Response, AnyFeathersError> {
        return SignalProducer { [weak self] observer, disposable in
            guard let vSelf = self else {
                observer.sendInterrupted()
                return
            }
            let request = vSelf.buildRequest(from: endpoint)
            Alamofire.request(request)
                .validate()
                .response(responseSerializer: DataRequest.jsonResponseSerializer()) { [weak self] response in
                    guard let vSelf = self else { return }
                    let result = vSelf.handleResponse(response)
                    if let error = result.error {
                        observer.send(error: error)
                    } else if let response = result.value {
                        observer.send(value: response)
                    } else {
                        observer.send(error: AnyFeathersError(FeathersNetworkError.unknown))
                    }
            }
        }
    }

    public final func authenticate(_ path: String, credentials: [String: Any]) -> SignalProducer<Response, AnyFeathersError> {
        return authenticationRequest(path: path, method: .post, parameters: credentials, encoding: URLEncoding.httpBody)
    }

    public func logout(path: String) -> SignalProducer<Response, AnyFeathersError> {
        return authenticationRequest(path: path, method: .delete, parameters: nil, encoding: URLEncoding.default)
    }

    public func on(event: String) -> Signal<[String : Any], NoError> {
        return .empty
    }

    public func once(event: String) -> Signal<[String : Any], NoError> {
        return .empty
    }

    public func off(event: String) {
        // no-op
    }

    // MARK: - Helpers

    /// Perform an authentication request.
    ///
    /// - Parameters:
    ///   - path: Authentication service path.
    ///   - method: HTTP method.
    ///   - parameters: Parameters.
    ///   - encoding: Parameter encoding.
    ///   - completion: Completion block.
    private func authenticationRequest(path: String, method: HTTPMethod, parameters: [String: Any]?, encoding: ParameterEncoding) -> SignalProducer<Response, AnyFeathersError>{
        return SignalProducer { [weak self] observer, disposable in
            guard let vSelf = self else {
                observer.sendInterrupted()
                return
            }
            Alamofire.request(vSelf.baseURL.appendingPathComponent(path), method: method, parameters: parameters, encoding: encoding)
                .validate()
                .response(responseSerializer: DataRequest.jsonResponseSerializer()) { response in
                    let result = vSelf.handleResponse(response)
                    if let error = result.error {
                        observer.send(error: error)
                    } else if let response = result.value {
                        observer.send(value: response)
                    } else {
                        observer.send(error: AnyFeathersError(FeathersNetworkError.unknown))
                    }
            }
        }
    }

    /// Handle the data response from an Alamofire request.
    ///
    /// - Parameter dataResponse: Alamofire data response.
    /// - Returns: Result with an error or a successful response.
    private func handleResponse(_ dataResponse: DataResponse<Any>) -> Result<Response, AnyFeathersError> {
        // If the status code maps to a feathers error code, return that error.
        if let statusCode = dataResponse.response?.statusCode,
            let feathersError = FeathersNetworkError(statusCode: statusCode) {
            return .failure(AnyFeathersError(feathersError))
        } else if let error = dataResponse.error {
            // If the data response has an error, wrap it and return it.
            return .failure(AnyFeathersError(FeathersNetworkError(error: error)))
        } else if let value = dataResponse.value {
            // If the response value is an array, there is no pagination.
            if let jsonArray = value as? [Any] {
                return .success(Response(pagination: nil, data: .list(jsonArray)))
            } else if let jsonDictionary = value as? [String: Any] {
                // If the value is a json dictionary, it can be one of two cases:
                // 1: The json object is wrapping the data with pagination information
                // 2: The response is returning an object right from the server i.e. a GET, POST, etc
                if let skip = jsonDictionary["skip"] as? Int,
                    let limit = jsonDictionary["limit"] as? Int,
                    let total = jsonDictionary["total"] as? Int,
                    let dataArray = jsonDictionary["data"] as? [Any] {
                    return .success(Response(pagination: Pagination(total: total, limit: limit, skip: skip), data: .list(dataArray)))
                } else {
                    return .success(Response(pagination: nil, data: .object(value)))
                }
            }
        }
        return .failure(AnyFeathersError(FeathersNetworkError.unknown))
    }

    /// Build a request from the given endpiont.
    ///
    /// - Parameter endpoint: Request endpoint.
    /// - Returns: Request object.
    private func buildRequest(from endpoint: Endpoint) -> URLRequest {
        var urlRequest = URLRequest(url: endpoint.url)
        urlRequest.httpMethod = endpoint.method.httpMethod.rawValue
        if let accessToken = endpoint.accessToken {
            urlRequest.allHTTPHeaderFields = [endpoint.authenticationConfiguration.header: accessToken]
        }
        urlRequest.httpBody = endpoint.method.data != nil ? try? JSONSerialization.data(withJSONObject: endpoint.method.data!, options: []) : nil
        return urlRequest
    }

}

fileprivate extension Service.Method {

    fileprivate var httpMethod: HTTPMethod {
        switch self {
        case .find: return .get
        case .get: return .get
        case .create: return .post
        case .update: return .put
        case .patch: return .patch
        case .remove: return .delete
        }
    }

}

fileprivate extension URL {

    /// Create a url by appending query parameters.
    ///
    /// - Parameter parameters: Query parameters.
    /// - Returns: New url with query parameters appended to the end.
    fileprivate func URLByAppendingQueryParameters(parameters: [String: Any]) -> URL? {
        guard var urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return self
        }
        urlComponents.queryItems = urlComponents.queryItems ?? [] + parameters.map { URLQueryItem(name: $0, value: "\($1)") }
        return urlComponents.url
    }
    
}

fileprivate extension Endpoint {

    fileprivate var url: URL {
        var url = baseURL.appendingPathComponent(path)
        switch method {
        case .get(let id, _):
            url = url.appendingPathComponent(id)
        case .update(let id, _, _),
             .patch(let id, _, _),
             .remove(let id, _):
            url = id != nil ? url.appendingPathComponent(id!) : url
        default: break
        }
        url = method.parameters != nil ? (url.URLByAppendingQueryParameters(parameters: method.parameters!) ?? url) : url
        return url
    }
    
}

public extension Service.Method {

    public var id: String? {
        switch self {
        case .get(let id, _): return id
        case .update(let id, _, _),
             .patch(let id, _, _): return id
        case .remove(let id, _): return id
        default: return nil
        }
    }

    public var parameters: [String: Any]? {
        switch self {
        case .find(let query): return query?.serialize()
        case .get(_, let query): return query?.serialize()
        case .create(_, let query): return query?.serialize()
        case .update(_, _, let query): return query?.serialize()
        case .patch(_, _, let query): return query?.serialize()
        case .remove(_, let query): return query?.serialize()
        }
    }

    public var data: [String: Any]? {
        switch self {
        case .create(let data, _): return data
        case .update(_, let data, _): return data
        case .patch(_, let data, _): return data
        default: return nil
        }
    }
    
}

