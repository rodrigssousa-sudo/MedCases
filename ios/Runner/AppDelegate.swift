import Flutter
import UIKit
import Firebase

// BUILD 279 — Anti-Flash iOS: sincronismo nativo entre LaunchScreen.storyboard e Flutter.
//
// PROBLEMA: o storyboard nativo encerra antes da árvore de widgets Flutter estar
// renderizada. O UIWindow exibe sua backgroundColor padrão (branco/transparente)
// por 1-3 frames → flash branco visível → risco de rejeição App Store (Guideline 2.1).
//
// SOLUÇÃO (3 camadas):
//   1. LaunchScreen.storyboard → backgroundColor #0F1116 (já corrigido no XML)
//   2. UIWindow.backgroundColor = #0F1116 (esta camada — cobertura nativa UIKit)
//   3. MaterialApp.color + builder Container dark (camada Flutter — main.dart)
//
// A cor #0F1116 é idêntica ao scaffoldBackgroundColor do dark theme do MedCases,
// garantindo transição invisível entre storyboard → UIKit → Flutter.

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)

    // BUILD 279: força a cor de fundo da UIWindow para o dark background do MedCases.
    // Executado APÓS super.application() para garantir que a window já foi criada
    // pelo FlutterAppDelegate. Cobre o gap entre LaunchScreen e o primeiro frame Flutter.
    // #0F1116 = red:15 green:17 blue:22 (sRGB) → mesmo que scaffoldBackgroundColor dark.
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let window = self.window {
      window.backgroundColor = UIColor(
        red: 15.0 / 255.0,
        green: 17.0 / 255.0,
        blue: 22.0 / 255.0,
        alpha: 1.0
      )
    }
    return result
  }
}
