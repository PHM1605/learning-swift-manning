import UIKit

extension UIFont {
    // "convenience init": call another standard init()
    // "convenience init?": failable init i.e. can "return nil object" if error happens
    convenience init?(
        familyName:String, // substring of the full name OR full name (more accurate) (e.g. "Quicksand")
        size: CGFloat = UIFont.systemFontSize,
        variantName: String? = nil
    ) {
        guard let name = UIFont.familyNames // load all available names // ["Helvetica", "Arial", "Quicksand", "Lobster"]
            .filter({ $0.contains(familyName) }) // ["Quicksand"]
            .flatMap( { UIFont.fontNames(forFamilyName: $0) } ) // ["Quicksand-Bold", "Quicksand-Regular", nil, nil, ...]
            .filter({ variantName != nil ? $0.contains(variantName!) : true }) // variantName="Bold" => return [1st]; otherwise all 2
            .first // take 1st element from list "Quicksand-Bold"
            else { return nil }
        self.init(name: name, size: size)
    }
}

struct Theme {
    static func apply() {
        guard let headerFont = UIFont(familyName: "Lobster", size: UIFont.systemFontSize*2) else {
            NSLog("Failed to load header font")
            return
        }
        guard let primaryFont = UIFont(familyName: "Quicksand") else {
            NSLog("Failed to load application font")
            return
        }
        let tintColor = #colorLiteral(red: 0.56, green: 0.35, blue: 0.97, alpha: 1)
        UIApplication.shared.delegate?.window??.tintColor = tintColor
        // Components aliases - return UIAppearance
        let navBarLabel = UILabel.appearance(
            whenContainedInInstancesOf: [UINavigationBar.self]
        )
        let barButton = UIBarButtonItem.appearance()
        let buttonLabel = UILabel.appearance(
            whenContainedInInstancesOf: [UIButton.self]
        )
        let navBar = UINavigationBar.appearance()
        let label = UILabel.appearance()
        // theming Navbar
        navBar.titleTextAttributes = [.font: headerFont]
        navBarLabel.font = primaryFont
        // theming labels
        label.font = primaryFont
        // theming buttons
        barButton.setTitleTextAttributes([.font: primaryFont], for: .normal)
        barButton.setTitleTextAttributes([.font: primaryFont], for: .highlighted)
        buttonLabel.font = primaryFont
    }
}
