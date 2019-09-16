//
//  RestProvider.swift
//  FeathersSwiftRest
//
//  Created by Brendan Conron on 5/16/17.
//  Copyright © 2017 FeathersJS. All rights reserved.
//

import Foundation
import Alamofire
import Result
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

    public final func setup(app: Feathers) {
        //no-op
    }

    public func request(endpoint: Endpoint) -> SignalProducer<Response, FeathersError> {
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
                        //send correct error here
                        observer.send(error: error)
                    } else if let response = result.value {
                        observer.send(value: response)
                    } else {
                        observer.send(error: FeathersError(reason: "No value in response"))
                    }
            }
        }
    }

    public final func authenticate(_ path: String, credentials: [String: Any]) -> SignalProducer<Response, FeathersError> {
        return authenticationRequest(path: path, method: .post, parameters: credentials, encoding: URLEncoding.httpBody)
    }

    public func logout(path: String) -> SignalProducer<Response, FeathersError> {
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
    private func authenticationRequest(path: String, method: HTTPMethod, parameters: [String: Any]?, encoding: ParameterEncoding) -> SignalProducer<Response, FeathersError>{
        return SignalProducer { [weak self] observer, disposable in
            guard let vSelf = self else {
                observer.sendInterrupted()
                return
            }
            
            let pathString = vSelf.baseURL.absoluteString.last == "/" ? String(path.dropFirst()) : path
            Alamofire.request(vSelf.baseURL.appendingPathComponent(pathString), method: method, parameters: parameters, encoding: encoding)
                .validate()
                .response(responseSerializer: DataRequest.jsonResponseSerializer()) { response in
                    let result = vSelf.handleResponse(response)
                    if let error = result.error {
                        observer.send(error: error)
                    } else if let response = result.value {
                        observer.send(value: response)
                    } else {
                        observer.send(error: FeathersError(reason: "No value in response"))
                    }
            }
        }
    }

    /// Handle the data response from an Alamofire request.
    ///
    /// - Parameter dataResponse: Alamofire data response.
    /// - Returns: Result with an error or a successful response.
    private func handleResponse(_ dataResponse: DataResponse<Any>) -> Swift.Result<Response, FeathersError> {
        // If the status code maps to a feathers error code, return that error.
        if let statusCode = dataResponse.response?.statusCode {
            let feathersError = FeathersError(payload: [:], statusCode: statusCode)
            return .failure(feathersError)
        } else if let error = dataResponse.error {
            // If the data response has an error, wrap it and return it.
            return .failure(FeathersError(error: error))
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
        return .failure(FeathersError(reason: "No value in response"))
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
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = endpoint.method.data != nil ? try? JSONSerialization.data(withJSONObject: endpoint.method.data!, options: []) : nil
        return urlRequest
    }

}

fileprivate extension Service.Method {

    var httpMethod: HTTPMethod {
    /// Mapping of feathers method to http method
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
    func URLByAppendingQueryParameters(parameters: [String: Any]) -> URL? {
        guard var urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return self
        }
        var items: [URLQueryItem] = []
        
        for (key, value) in parameters {
            if let valueDict = value as? [String: Any] {
                let valueDictKeys = Array(valueDict.keys)
                for nestedKey in valueDictKeys {
                    let type = PropertySubquerySet.type(for: nestedKey)
                    switch type {
                    case .array:
                        guard let valuesArray = valueDict[nestedKey] as? [String] else {
                            continue
                        }
                        for (index, object) in valuesArray.enumerated() {
                            items.append(URLQueryItem(name: "\(key)[\(nestedKey)][\(index)]", value: "\(object)"))
                        }
                    case .singleValue:
                        items.append(URLQueryItem(name: "\(key)[\(nestedKey)]", value: "\(valueDict[nestedKey]!)"))
                    case .sort:
                        items.append(URLQueryItem(name: "\(key)[\(nestedKey)]", value: "\(valueDict[nestedKey]!)"))
                    }
                }
            } else {
                items.append(URLQueryItem(name: key, value: "\(value)"))
            }
        }
        urlComponents.queryItems = items
        return urlComponents.url
    }
    
}

fileprivate extension Endpoint {

    var url: URL {
    /// Builds url according to endpoints' method
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

    var id: String? {
        switch self {
        case .get(let id, _): return id
        case .update(let id, _, _),
             .patch(let id, _, _): return id
        case .remove(let id, _): return id
        default: return nil
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .find(let query): return query?.serialize()
        case .get(_, let query): return query?.serialize()
        case .create(_, let query): return query?.serialize()
        case .update(_, _, let query): return query?.serialize()
        case .patch(_, _, let query): return query?.serialize()
        case .remove(_, let query): return query?.serialize()
        }
    }

    var data: [String: Any]? {
        switch self {
        case .create(let data, _): return data
        case .update(_, let data, _): return data
        case .patch(_, let data, _): return data
        default: return nil
        }
    }
    
}

