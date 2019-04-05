//
//  PropertySubquerySet.swift
//  FeathersSwiftRest-iOS
//
//  Created by Ostap Holub on 3/26/19.
//  Copyright © 2019 FeathersJS. All rights reserved.
//

import Foundation

enum PropertySubqueryType {
    case array
    case singleValue
    case sort
}

class PropertySubquerySet {
    
    private class var array: Set<String> {
        return Set<String>(["$in", "$nin"])
    }
    
    private class var singleValueProperty: Set<String> {
        return Set<String>(["$gt", "$gte", "$lt", "$lte", "$ne"])
    }
    
    class func type(for subqueryName: String) -> PropertySubqueryType {
        
        if array.contains(subqueryName) {
            return .array
        } else if singleValueProperty.contains(subqueryName) {
            return .singleValue
        }
        
        return .sort
    }
}
