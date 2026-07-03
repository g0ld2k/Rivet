import FoundationModels

public enum ModelGate {
    public static func explain(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            "this Mac's hardware does not support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is turned off. Enable it in System Settings > Apple Intelligence & Siri."
        case .modelNotReady:
            "the on-device model is still downloading or preparing. Try again in a few minutes."
        @unknown default:
            "the on-device model is unavailable for an unrecognized reason."
        }
    }

    public static func ensureAvailable(_ model: SystemLanguageModel) throws {
        if case .unavailable(let reason) = model.availability {
            throw RivetError.modelUnavailable(explain(reason))
        }
    }
}

public enum GenerationFailure {
    public static func rivetError(from error: any Error) -> RivetError {
        if let error = error as? RivetError { return error }
        if let error = error as? LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                return .generationFailed("prompt exceeded the model's context window — this is a Rivet budgeting bug; please report it with `--verbose` output attached")
            case .guardrailViolation:
                return .generationFailed("the on-device model's safety guardrails rejected this diff's content")
            case .rateLimited:
                return .generationFailed("the system is rate-limiting model requests; try again shortly")
            case .refusal:
                return .generationFailed("the model declined to write a message for this change")
            case .assetsUnavailable:
                return .modelUnavailable("model assets became unavailable mid-request; run `rivet doctor`")
            case .concurrentRequests:
                return .generationFailed("another Foundation Models request is already running")
            default:
                return .generationFailed(error.localizedDescription)
            }
        }
        return .generationFailed(String(describing: error))
    }
}
