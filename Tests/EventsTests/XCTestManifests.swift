import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(EventBuilderTests.allTests),
        testCase(EventTests.allTests),
    ]
}
#endif
