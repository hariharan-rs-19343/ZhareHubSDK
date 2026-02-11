//
//  Bundle+.swift
//  ZhareHub
//
//  Created by Hariharan R S on 20/11/24.
//

import Foundation

public extension Bundle {
    static var appVersion: String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    enum ApplicationCategory: String, CaseIterable {
        case business = "public.app-category.business"
        case developerTools = "public.app-category.developer-tools"
        case education = "public.app-category.education"
        case entertainment = "public.app-category.entertainment"
        case finance = "public.app-category.finance"
        case games = "public.app-category.games"
        case actionGames = "public.app-category.action-games"
        case adventureGames = "public.app-category.adventure-games"
        case arcadeGames = "public.app-category.arcade-games"
        case boardGames = "public.app-category.board-games"
        case cardGames = "public.app-category.card-games"
        case casinoGames = "public.app-category.casino-games"
        case diceGames = "public.app-category.dice-games"
        case educationalGames = "public.app-category.educational-games"
        case familyGames = "public.app-category.family-games"
        case kidsGames = "public.app-category.kids-games"
        case musicGames = "public.app-category.music-games"
        case puzzleGames = "public.app-category.puzzle-games"
        case racingGames = "public.app-category.racing-games"
        case rolePlayingGames = "public.app-category.role-playing-games"
        case simulationGames = "public.app-category.simulation-games"
        case sportsGames = "public.app-category.sports-games"
        case strategyGames = "public.app-category.strategy-games"
        case triviaGames = "public.app-category.trivia-games"
        case wordGames = "public.app-category.word-games"
        case graphicsDesign = "public.app-category.graphics-design"
        case healthcareFitness = "public.app-category.healthcare-fitness"
        case lifestyle = "public.app-category.lifestyle"
        case medical = "public.app-category.medical"
        case music = "public.app-category.music"
        case news = "public.app-category.news"
        case photography = "public.app-category.photography"
        case productivity = "public.app-category.productivity"
        case reference = "public.app-category.reference"
        case socialNetworking = "public.app-category.social-networking"
        case sports = "public.app-category.sports"
        case travel = "public.app-category.travel"
        case utilities = "public.app-category.utilities"
        case video = "public.app-category.video"
        case weather = "public.app-category.weather"
        
        public var friendlyName: String {
            switch self {
            case .business: return "Business"
            case .developerTools: return "Developer Tools"
            case .education: return "Education"
            case .entertainment: return "Entertainment"
            case .finance: return "Finance"
            case .games: return "Games"
            case .actionGames: return "Action Games"
            case .adventureGames: return "Adventure Games"
            case .arcadeGames: return "Arcade Games"
            case .boardGames: return "Board Games"
            case .cardGames: return "Card Games"
            case .casinoGames: return "Casino Games"
            case .diceGames: return "Dice Games"
            case .educationalGames: return "Educational Games"
            case .familyGames: return "Family Games"
            case .kidsGames: return "Kids Games"
            case .musicGames: return "Music Games"
            case .puzzleGames: return "Puzzle Games"
            case .racingGames: return "Racing Games"
            case .rolePlayingGames: return "Role-Playing Games"
            case .simulationGames: return "Simulation Games"
            case .sportsGames: return "Sports Games"
            case .strategyGames: return "Strategy Games"
            case .triviaGames: return "Trivia Games"
            case .wordGames: return "Word Games"
            case .graphicsDesign: return "Graphics & Design"
            case .healthcareFitness: return "Healthcare & Fitness"
            case .lifestyle: return "Lifestyle"
            case .medical: return "Medical"
            case .music: return "Music"
            case .news: return "News"
            case .photography: return "Photography"
            case .productivity: return "Productivity"
            case .reference: return "Reference"
            case .socialNetworking: return "Social Networking"
            case .sports: return "Sports"
            case .travel: return "Travel"
            case .utilities: return "Utilities"
            case .video: return "Video"
            case .weather: return "Weather"
            }
        }
    }
}
