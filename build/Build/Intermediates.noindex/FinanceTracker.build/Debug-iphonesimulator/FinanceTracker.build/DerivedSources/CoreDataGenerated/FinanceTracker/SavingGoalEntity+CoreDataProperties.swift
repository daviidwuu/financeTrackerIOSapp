//
//  SavingGoalEntity+CoreDataProperties.swift
//  
//
//  Created by david wu on 12/16/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias SavingGoalEntityCoreDataPropertiesSet = NSSet

extension SavingGoalEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SavingGoalEntity> {
        return NSFetchRequest<SavingGoalEntity>(entityName: "SavingGoalEntity")
    }

    @NSManaged public var colorHex: String?
    @NSManaged public var currentAmount: Double
    @NSManaged public var icon: String?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var targetAmount: Double
    @NSManaged public var targetDate: Date?
    @NSManaged public var userId: String?

}

extension SavingGoalEntity : Identifiable {

}
