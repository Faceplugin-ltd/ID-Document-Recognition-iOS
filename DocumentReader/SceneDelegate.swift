import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: ViewController())
        window.tintColor = FPColor.accent
        window.backgroundColor = FPColor.bg
        window.makeKeyAndVisible()
        self.window = window
        if #available(iOS 13.0, *) {
            window.overrideUserInterfaceStyle = .dark
        }
    }
}

enum FPColor {
    static let bg = UIColor(red: 0.043, green: 0.071, blue: 0.125, alpha: 1)
    static let text = UIColor(red: 0.910, green: 0.933, blue: 0.969, alpha: 1)
    static let muted = UIColor(red: 0.545, green: 0.608, blue: 0.706, alpha: 1)
    static let accent = UIColor(red: 0.180, green: 0.902, blue: 0.651, alpha: 1)
    static let accentDim = UIColor(red: 0.180, green: 0.902, blue: 0.651, alpha: 0.22)
    static let purple = UIColor(red: 0.380, green: 0.239, blue: 0.557, alpha: 1)
    static let surface = UIColor(red: 0.078, green: 0.118, blue: 0.184, alpha: 1)
    static let stroke = UIColor(red: 0.180, green: 0.227, blue: 0.310, alpha: 1)
    static let statusOk = UIColor(red: 0.220, green: 0.557, blue: 0.235, alpha: 1)
    static let statusError = UIColor(red: 0.827, green: 0.184, blue: 0.184, alpha: 1)
    static let statusInfo = UIColor(red: 0.098, green: 0.463, blue: 0.824, alpha: 1)
    static let overlay = UIColor(red: 0.043, green: 0.071, blue: 0.125, alpha: 0.80)
}
