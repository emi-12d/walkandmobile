//
//  CodeBlock+CoreDataProperties.swift
//  
//
//  Created by RyoNishimura on 2021/10/19.
//
//

import Foundation
import CoreData


extension CodeBlock {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CodeBlock> {
        return NSFetchRequest<CodeBlock>(entityName: "CodeBlock")
    }

    @NSManaged public var angle: Int16
    @NSManaged public var code: Int32
    @NSManaged public var message: String?
    @NSManaged public var reading: String?
    @NSManaged public var messagecategory: String?

}
