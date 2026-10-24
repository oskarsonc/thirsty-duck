import CoreGraphics

public enum Palette: String, CaseIterable, Sendable {
    case classic, mint, bubblegum, sky, lavender, peach, snow, charcoal, lime, ocean
    case mallard, strawberry, sunset, cow, chick, golden, rainbow, galaxy, ghost, robot

    public var isRare: Bool {
        switch self {
        case .golden, .rainbow, .galaxy, .ghost, .robot: true
        default: false
        }
    }
}

public enum Hat: String, CaseIterable, Sendable {
    case party = "H1", beanie = "H2", topHat = "H3", crown = "H4", cowboy = "H5", cap = "H6"
    case chef = "H7", witch = "H8", flower = "H9", bow = "H10", propeller = "H11", santa = "H12"
    case headphones = "H13", frog = "H14", viking = "H15", halo = "H16", sprout = "H17"
    case gradCap = "H18", pirate = "H19", bunny = "H20", bucket = "H21", sailor = "H22"

    var headroom: Int {
        switch self {
        case .party, .chef, .bunny: 5
        case .beanie, .crown, .flower, .frog, .viking, .sprout, .gradCap, .pirate, .bucket: 3
        case .topHat, .cowboy, .propeller, .santa, .halo: 4
        case .cap, .bow, .sailor: 2
        case .witch: 6
        case .headphones: 1
        }
    }
}

public enum Glasses: String, CaseIterable, Sendable {
    case round = "G1", sunglasses = "G2", heart = "G3", threeD = "G4", monocle = "G5", nerd = "G6"
    case star = "G7", swimGoggles = "G8", skiGoggles = "G9", pixelShades = "G10", eyePatch = "G11", catEye = "G12"
}

public enum Outfit: String, CaseIterable, Sendable {
    case scarf = "O1", bowTie = "O2", tShirt = "O3", stripedSweater = "O4", hoodie = "O5", raincoat = "O6"
    case sailorTop = "O7", lifeJacket = "O8", cape = "O9", tutu = "O10", swimRing = "O11", overalls = "O12"
    case hawaiianShirt = "O13", tie = "O14", tuxedo = "O15", goldChain = "O16", bandana = "O17", backpack = "O18"
}

public enum HeldItem: String, CaseIterable, Sendable {
    case waterBottle = "I1", glassOfWater = "I2", umbrella = "I3", balloon = "I4", flower = "I5"
    case lollipop = "I6", fish = "I7", skateboard = "I8", duckling = "I9"

    public var artBoundsInCells: CGRect {
        switch self {
        case .waterBottle: CGRect(x: 12, y: 5, width: 3, height: 6)
        case .glassOfWater: CGRect(x: 13, y: 5, width: 3, height: 6)
        case .umbrella: CGRect(x: 2, y: -7, width: 11, height: 6)
        case .balloon: CGRect(x: 12, y: -8, width: 4, height: 10)
        case .flower: CGRect(x: 13, y: 1, width: 3, height: 3)
        case .lollipop: CGRect(x: 13, y: 0, width: 3, height: 4)
        case .fish: CGRect(x: 13, y: 3, width: 7, height: 2)
        case .skateboard: CGRect(x: 1, y: 13, width: 14, height: 3)
        case .duckling: CGRect(x: -6, y: 8, width: 6, height: 6)
        }
    }
}

public struct Look: Equatable, Sendable {
    public var palette: Palette
    public var hat: Hat?
    public var glasses: Glasses?
    public var outfit: Outfit?
    public var item: HeldItem?

    public init(palette: Palette, hat: Hat? = nil, glasses: Glasses? = nil, outfit: Outfit? = nil, item: HeldItem? = nil) {
        self.palette = palette
        self.hat = hat
        self.glasses = glasses
        self.outfit = outfit
        self.item = item
    }

    public static let classic = Look(palette: .classic)

    public static func random<R: RandomNumberGenerator>(using rng: inout R, unlike previous: Look?) -> Look {
        while true {
            let rare = Double.random(in: 0..<1, using: &rng) < 0.06
            let palette = Palette.allCases.filter { $0.isRare == rare }.randomElement(using: &rng)!
            let item = Double.random(in: 0..<1, using: &rng) < 0.18 ? HeldItem.allCases.randomElement(using: &rng) : nil
            let hasHat = Double.random(in: 0..<1, using: &rng) < 0.70
            let hat = hasHat && item != .umbrella ? Hat.allCases.randomElement(using: &rng) : nil
            let glasses = Double.random(in: 0..<1, using: &rng) < 0.35 ? Glasses.allCases.randomElement(using: &rng) : nil
            let outfit = Double.random(in: 0..<1, using: &rng) < 0.60 ? Outfit.allCases.randomElement(using: &rng) : nil
            let look = Look(palette: palette, hat: hat, glasses: glasses, outfit: outfit, item: item)
            if look != previous { return look }
        }
    }

    public var headroom: Int { max(hat?.headroom ?? 0, item == .umbrella ? 7 : 0) }

    public var isAnimated: Bool {
        [.golden, .rainbow, .galaxy, .ghost].contains(palette)
            || hat == .propeller || hat == .halo || outfit == .scarf || outfit == .cape
    }
}
