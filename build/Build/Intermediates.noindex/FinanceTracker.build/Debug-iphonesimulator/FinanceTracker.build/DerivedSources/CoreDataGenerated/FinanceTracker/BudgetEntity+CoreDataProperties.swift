//
//  BudgetEntity+CoreDataProperties.swift
//  
//
//  Created by david wu on 12/16/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias BudgetEntityCoreDataPropertiesSet = NSSet

extension BudgetEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BudgetEntity> {
        return NSFetchRequest<BudgetEntity>(entityName: "BudgetEntity")
    }

    @NSManaged public var category: String?
    @NSManaged public var colorHex: String?
    @NSManaged public var frequency: String?
    @NSManaged public var icon: String?
    @NSManaged public var id: UUID?
    @NSManaged public var remainingAmount: Double
    @NSManaged public var totalAmount: Double
    @NSManaged public var userId: String?

}

extension BudgetEntity : Identifiable {

}
