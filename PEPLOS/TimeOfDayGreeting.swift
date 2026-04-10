//
//  TimeOfDayGreeting.swift
//  PEPLOS
//

import Foundation

enum TimeOfDayGreeting {
    enum Period {
        case morning
        case afternoon
        case evening
        case night

        var message: String {
            switch self {
            case .morning:
                return "Good Morning"
            case .afternoon:
                return "Good Afternoon"
            case .evening:
                return "Good Evening"
            case .night:
                return "Good Night"
            }
        }
    }

    /// Localized greeting from the device calendar hour.
    static func message(for date: Date = Date(), calendar: Calendar = .current) -> String {
        period(for: date, calendar: calendar).message
    }

    static func period(for date: Date = Date(), calendar: Calendar = .current) -> Period {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5 ..< 12:
            return .morning
        case 12 ..< 17:
            return .afternoon
        case 17 ..< 22:
            return .evening
        default:
            return .night
        }
    }
}
