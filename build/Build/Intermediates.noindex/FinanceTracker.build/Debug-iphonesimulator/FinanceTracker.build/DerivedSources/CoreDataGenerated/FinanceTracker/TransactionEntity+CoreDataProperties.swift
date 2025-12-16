//
//  TransactionEntity+CoreDataProperties.swift
//  
//
//  Created by david wu on 12/16/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias TransactionEntityCoreDataPropertiesSet = NSSet

extension TransactionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TransactionEntity> {
        return NSFetchRequest<TransactionEntity>(entityName: "TransactionEntity")
    }

    @NSManaged public var amount: Double
    @NSManaged public var colorHex: String?
    @NSManaged public var date: Date?
    @NSManaged public var icon: String?
    @NSManaged public var id: UUID?
    @NSManaged public var note: String?
    @NSManaged public var subtitle: String?
    @NSManaged public var title: String?
    @NSManaged public var type: String?
    @NSManaged public var userId: String?

}

extension TransactionEntity : Identifiable {

}
