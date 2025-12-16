//
//  RecurringTransactionEntity+CoreDataProperties.swift
//  
//
//  Created by david wu on 12/16/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias RecurringTransactionEntityCoreDataPropertiesSet = NSSet

extension RecurringTransactionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecurringTransactionEntity> {
        return NSFetchRequest<RecurringTransactionEntity>(entityName: "RecurringTransactionEntity")
    }

    @NSManaged public var amount: Double
    @NSManaged public var colorHex: String?
    @NSManaged public var frequency: String?
    @NSManaged public var icon: String?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var note: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var userId: String?

}

extension RecurringTransactionEntity : Identifiable {

}
