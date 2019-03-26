//
//  PropertySubquerySet.swift
//  FeathersSwiftRest-iOS
//
//  Created by Ostap Holub on 3/26/19.
//  Copyright © 2019 FeathersJS. All rights reserved.
//

import Foundation

class PropertySubquerySet {
    
    class var pagination: Set<String> {
        return Set<String>(["$skip", "$limit"])
    }
    
    class var array: Set<String> {
        return Set<String>(["$in", "$nin"])
    }
    
    class var singleValueProperty: Set<String> {
        return Set<String>(["$gt", "$gte", "$lt", "$lte", "$ne"])
    }
}
