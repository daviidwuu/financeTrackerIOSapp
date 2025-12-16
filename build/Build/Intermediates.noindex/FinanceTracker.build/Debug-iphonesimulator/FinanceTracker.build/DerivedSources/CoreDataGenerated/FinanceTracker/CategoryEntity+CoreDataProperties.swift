//
//  CategoryEntity+CoreDataProperties.swift
//  
//
//  Created by david wu on 12/16/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias CategoryEntityCoreDataPropertiesSet = NSSet

extension CategoryEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CategoryEntity> {
        return NSFetchRequest<CategoryEntity>(entityName: "CategoryEntity")
    }

    @NSManaged public var colorHex: String?
    @NSManaged public var icon: String?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var type: String?
    @NSManaged public var userId: String?

}

extension CategoryEntity : Identifiable {

}
