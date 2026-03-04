import Foundation

/// A thread-safe generic memoizer for caching expensive computations.
public final class Memoization<Input: Hashable, Output> {
    private var cache: [Input: Output] = [:]
    private let queue = DispatchQueue(label: "com.financetracker.memoization", attributes: .concurrent)
    
    public init() {}
    
    deinit {}
    
    /// Clears the cache. Useful for memory warnings or data resets.
    public func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    /// Returns the cached result for the given input, or computes it, caches it, and returns it.
    public func get(for input: Input, compute: (Input) -> Output) -> Output {
        var existing: Output?
        queue.sync {
            existing = cache[input]
        }
        
        if let cached = existing {
            return cached
        }
        
        // Compute outside the lock to prevent blocking other reads
        let result = compute(input)
        
        queue.async(flags: .barrier) {
            self.cache[input] = result
        }
        
        return result
    }
}
