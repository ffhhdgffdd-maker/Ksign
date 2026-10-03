//
//  Persistence.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import CoreData

// MARK: - Class
final class Storage: ObservableObject {
	static let shared = Storage()
	let container: NSPersistentContainer
    @Published private(set) var startupError: String?
	
	private let _name: String = "Feather"
	
	init(inMemory: Bool = false) {
		container = NSPersistentContainer(name: _name)
		
		if inMemory {
			container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
		}
		
		for description in container.persistentStoreDescriptions {
            description.shouldAddStoreAsynchronously = false
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
			if let error = error as NSError? {
				self.startupError = error.localizedDescription
			}
		})
		
		container.viewContext.automaticallyMergesChangesFromParent = true
	}
	
	var context: NSManagedObjectContext {
		container.viewContext
	}
	
	func saveContext() {
        DispatchQueue.main.async {
            if self.context.hasChanges {
                try? self.context.save()
            }
        }
	}
	
	func clearContext<T: NSManagedObject>(request: NSFetchRequest<T>) {
		let deleteRequest = NSBatchDeleteRequest(fetchRequest: (request as? NSFetchRequest<NSFetchRequestResult>)!)
		do {
			_ = try context.execute(deleteRequest)
		} catch {
			print("clear: \(error.localizedDescription)")
		}
	}
    
    func countContent<T: NSManagedObject>(for type: T.Type) -> String {
        let request = T.fetchRequest()
        return "\((try? context.count(for: request)) ?? 0)"
    }
}
