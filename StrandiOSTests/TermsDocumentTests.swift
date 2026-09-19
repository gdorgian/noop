#if os(iOS)
import XCTest
@testable import NOOP_Staging

/// The gate tells every user "The full terms are in TERMS.md, shipped with Noop Aura." These are the
/// tests that keep that sentence true.
///
/// Two failures had to become visible. The document was not in either app's resources, so nothing
/// could show it. And its header said Version 1.1 while `Terms.currentVersion` — the value the gate
/// actually stores and compares — had been moved to 2.0 by the clickwrap change, so the app was
/// enforcing one version of an agreement and shipping the text of another. Neither could fail
/// anything, because nothing read the file.
final class TermsDocumentTests: XCTestCase {

    // MARK: - The shipped document

    func testBundledDocumentIsPresent() throws {
        XCTAssertNotNil(TermsDocument.bundled,
                        "TERMS.md is not in the app bundle. The gate's claim that the full terms "
                        + "ship with the app is false without it, and plumbing/terms has nothing to "
                        + "render. Check the `TERMS.md` resource entry in project.yml.")
    }

    /// The drift guard. A change to the binding text that forgets the header, or a `currentVersion`
    /// bump that forgets the document, fails here rather than in front of a user.
    func testDeclaredVersionMatchesTheVersionTheGateEnforces() throws {
        let document = try XCTUnwrap(TermsDocument.bundled)
        XCTAssertEqual(document.version, Terms.currentVersion,
                       "TERMS.md declares version \(document.version ?? "none") but the gate stores "
                       + "and compares \(Terms.currentVersion). Move whichever one is behind.")
    }

    func testBundledDocumentHasTheNineNumberedSections() throws {
        let document = try XCTUnwrap(TermsDocument.bundled)
        XCTAssertEqual(document.sections.compactMap(\.number), Array(1...9))
        XCTAssertFalse(document.title.isEmpty)
        XCTAssertFalse(document.preamble.isEmpty, "The not-legal-advice note belongs to the document.")
        XCTAssertFalse(document.closing.isEmpty, "The closing note sits beneath the final rule.")
        for section in document.sections {
            XCTAssertFalse(section.heading.isEmpty, "section \(section.number.map(String.init) ?? "?")")
            XCTAssertFalse(section.body.isEmpty, "section \(section.number.map(String.init) ?? "?")")
        }
    }

    /// Section 5 carries the medical disclaimer and its three named sub-cases. It is the longest
    /// section and the one a screen is most likely to clip.
    func testMedicalSectionSurvivesTheParse() throws {
        let document = try XCTUnwrap(TermsDocument.bundled)
        let five = try XCTUnwrap(document.sections.first { $0.number == 5 })
        XCTAssertTrue(five.heading.lowercased().contains("medical"))
        XCTAssertTrue(five.body.contains("Mind / mood check-in"))
        XCTAssertTrue(five.body.contains("Nutrition import"))
        XCTAssertTrue(five.body.contains("Apple Health"))
    }

    // MARK: - The parse itself, without a bundle

    func testParseSplitsHeadingsNumbersPreambleAndClosing() {
        let document = TermsDocument.parse("""
        # Noop Aura — Terms

        **Version 9.9**

        > Not legal advice.

        Accept before continuing.

        ---

        ## 1. What it is

        A body paragraph.

        ## 2. Risk

        Another body.

        ---

        *A closing note.*
        """)

        XCTAssertEqual(document.title, "Noop Aura — Terms")
        XCTAssertEqual(document.version, "9.9")
        XCTAssertTrue(document.preamble.contains("Not legal advice."))
        XCTAssertTrue(document.preamble.contains("Accept before continuing."))
        XCTAssertFalse(document.preamble.hasSuffix("---"), "The rule is a separator, not content.")

        XCTAssertEqual(document.sections.count, 2)
        XCTAssertEqual(document.sections[0].number, 1)
        XCTAssertEqual(document.sections[0].heading, "What it is")
        XCTAssertEqual(document.sections[0].body, "A body paragraph.")
        XCTAssertEqual(document.sections[1].number, 2)
        XCTAssertEqual(document.sections[1].body, "Another body.",
                       "The closing note must not stay attached to the last section.")
        XCTAssertEqual(document.closing, "*A closing note.*")
    }

    func testUnnumberedHeadingKeepsItsWholeTitle() {
        let document = TermsDocument.parse("""
        # T

        ## Appendix

        Body.
        """)
        XCTAssertEqual(document.sections.count, 1)
        XCTAssertNil(document.sections[0].number)
        XCTAssertEqual(document.sections[0].heading, "Appendix")
    }

    /// A legal document that cannot be read must not take the app down with it. The caller falls
    /// back to `Terms.points`, which is compiled in and cannot go missing.
    func testMissingResourceYieldsNilRatherThanCrashing() {
        XCTAssertNil(TermsDocument.load(from: Bundle(for: XCTestCase.self)))
    }
}
#endif
