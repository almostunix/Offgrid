import Foundation

/// Utility functions for reordering tiles
public enum TileOrder {
    /// Moves an item in an array to a new position relative to a target item
    /// - Parameters:
    ///   - items: The array of items
    ///   - moving: The item to move
    ///   - target: The target item (the dropped-on item)
    /// - Returns: A new array with the item moved
    public static func move<T: Equatable>(_ items: [T], moving: T, onto target: T) -> [T] {
        // If moving onto itself or target not found, return unchanged
        guard moving != target, let targetIndex = items.firstIndex(of: target) else {
            return items
        }
        
        // Find the index of the item to move
        guard let movingIndex = items.firstIndex(of: moving) else {
            return items
        }
        
        // Remove the moving item
        var result = items
        let movedItem = result.remove(at: movingIndex)
        
        // Insert it at the target's index (after removal, so dropping C on B in [A,B,C] gives [A,C,B])
        result.insert(movedItem, at: targetIndex)
        
        return result
    }
}
