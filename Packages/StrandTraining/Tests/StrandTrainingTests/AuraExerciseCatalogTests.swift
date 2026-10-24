import XCTest
@testable import StrandTraining

final class AuraExerciseCatalogTests: XCTestCase {
    func testEntriesPassTheCatalogueValidation() {
        XCTAssertEqual(BundledExerciseCatalog.validationIssues(AuraExerciseCatalog.exercises), [])
        XCTAssertGreaterThanOrEqual(AuraExerciseCatalog.exercises.count, 150)
    }

    func testIdsAreNamespacedAndUniqueAcrossTheLibrary() {
        for exercise in AuraExerciseCatalog.exercises {
            XCTAssertTrue(exercise.id.hasPrefix("aura:"), exercise.id)
            XCTAssertEqual(exercise.source, .noop)
            XCTAssertEqual(exercise.attribution, "Noop Aura")
        }
        let ids = TrainingExerciseLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    /// An addition that repeats a name already offered would show twice in the picker.
    func testNoTitleRepeatsAnExistingExercise() {
        func fold(_ s: String) -> String { s.lowercased().replacingOccurrences(of: "-", with: " ") }
        let existing = Set((TrainingStarterCatalog.exercises + BundledExerciseCatalog.exercises).map { fold($0.title) })
        for exercise in AuraExerciseCatalog.exercises {
            XCTAssertFalse(existing.contains(fold(exercise.title)), exercise.title)
        }
        let titles = AuraExerciseCatalog.exercises.map { fold($0.title) }
        XCTAssertEqual(Set(titles).count, titles.count)
    }

    func testNewEquipmentIsKnownAndLoadedWhereItCarriesWeight() {
        XCTAssertTrue(TrainingEquipmentCatalog.isKnown("TRX"))
        XCTAssertEqual(TrainingEquipmentCatalog.canonical("trx"), "suspension-trainer")
        XCTAssertFalse(TrainingEquipmentCatalog.carriesExternalLoad(["suspension-trainer"]))
        XCTAssertTrue(TrainingEquipmentCatalog.carriesExternalLoad(["sandbag"]))
        XCTAssertTrue(TrainingEquipmentCatalog.carriesExternalLoad(["plate"]))
    }

    func testCommonMovementsArePresent() {
        let titles = Set(AuraExerciseCatalog.exercises.map(\.title))
        for title in ["Pec Deck Fly", "Hip Thrust Machine", "Bird Dog", "Hollow Hold", "Dead Hang", "Sled Push",
                      "Cable Pallof Press", "Copenhagen Plank", "Reverse Lunge", "Suspension Row", "Toes to Bar"] {
            XCTAssertTrue(titles.contains(title), title)
        }
    }
}
