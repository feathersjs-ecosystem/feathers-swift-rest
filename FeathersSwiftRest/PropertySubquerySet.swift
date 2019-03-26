//
//  PropertySubquerySet.swift
//  FeathersSwiftRest-iOS
//
//  Created by Ostap Holub on 3/26/19.
//  Copyright © 2019 FeathersJS. All rights reserved.
//

import Foundation

class PropertySubquerySet: Set<String> {
    
    class var pagination: PropertySubquerySet {
        return Set<String>(["$skip", "$limit"])
    }
    
    class var array: PropertySubquerySet {
        return Set<String>(["$in", "$nin"])
    }
    
    class var singleValueProperty: PropertySubquerySet {
        return Set<String>(["$gt", "$gte", "$lt", "$lte", "$ne"])
    }
}
