// Source: http://www.codeproject.com/Tips/226893/How-to-implement-a-queue-in-Objective-C
// Licensed under: The Code Project Open License (CPOL) 1.02 (http://www.codeproject.com/info/cpol10.aspx)

@interface SimpleQueue : NSObject {
    NSMutableArray* m_array;
}

- (void)enqueue:(id)anObject;
- (id)dequeue;
- (void)clear;

@property (nonatomic, readonly) int count;

@end