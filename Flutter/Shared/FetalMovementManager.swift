import Foundation
import SwiftData
import Observation
#if os(watchOS)
import WatchKit
#endif
#if os(iOS)
import UIKit
#endif

enum ClickStatus {
    case none
    case success
    case debounced
}

@Observable
final class FetalMovementManager {
    private var modelContext: ModelContext
    
    var activeSession: FetalMovementSession?
    var showValidityAlert: Bool = false
    var lastClickStatus: ClickStatus = .none
    var clickTrigger: Bool = false
    var rawClickCount: Int = 0
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func logMovement() {
        let now = Date()
        clickTrigger.toggle()
        
        if activeSession == nil {
            startNewSession(at: now)
            let record = FetalMovementRecord(timestamp: now, isValidated: true)
            activeSession?.records.append(record)
            triggerHapticFeedback(.success)
            lastClickStatus = .success
            saveContext()
            return
        }
        
        guard let session = activeSession else { return }
        rawClickCount += 1
        
        let validatedRecords = session.records.filter { $0.isValidated }.sorted(by: { $0.timestamp < $1.timestamp })
        var isValid = true
        if let lastValidRecord = validatedRecords.last {
            let timeSinceLast = now.timeIntervalSince(lastValidRecord.timestamp)
            if timeSinceLast < 5 * 60 {
                isValid = false
            }
        }
        
        let record = FetalMovementRecord(timestamp: now, isValidated: isValid)
        session.records.append(record)
        
        if isValid {
            triggerHapticFeedback(.success)
            lastClickStatus = .success
        } else {
            triggerHapticFeedback(.directionDown)
            lastClickStatus = .debounced
        }
        
        saveContext()
    }
    
    func tryEndSession() {
        guard let session = activeSession else { return }
        if !session.isDurationValid {
            showValidityAlert = true
        } else {
            finalizeSession(discard: false)
        }
    }
    
    func finalizeSession(discard: Bool) {
        guard let session = activeSession else { return }
        if discard {
            modelContext.delete(session)
        } else {
            session.endDate = Date()
        }
        activeSession = nil
        showValidityAlert = false
        lastClickStatus = .none
        rawClickCount = 0
        saveContext()
    }
    
    private func startNewSession(at date: Date) {
        let session = FetalMovementSession(startDate: date)
        modelContext.insert(session)
        activeSession = session
        rawClickCount = 0
        saveContext()
    }
    
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("DEBUG: Save ERROR: \(error)")
        }
    }
    
    private func triggerHapticFeedback(_ type: HapticType = .success) {
        #if os(watchOS)
        let wkType: WKHapticType = (type == .success) ? .success : .directionDown
        WKInterfaceDevice.current().play(wkType)
        #endif
        #if os(iOS)
        let style: UIImpactFeedbackGenerator.FeedbackStyle = (type == .success) ? .medium : .light
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        #endif
    }

    enum HapticType {
        case success
        case debounced
        case directionDown
    }
}
