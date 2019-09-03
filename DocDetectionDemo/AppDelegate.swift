//
//  AppDelegate.swift
//  DocDetectionDemo
//
//  Created by Ruben Nine on 28/08/2019.
//  Copyright © 2019 Filestack. All rights reserved.
//

import UIKit
import FilestackSDK

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        setupFilestackClient()

        return true
    }

    private func setupFilestackClient() {
        // Create `Policy` object with an expiry time and call permissions.
        let policy = Policy(expiry: .distantFuture,
                            call: [.pick, .read, .stat, .write, .writeURL, .store, .convert, .remove, .exif])

        // Create `Security` object based on our previously created `Policy` object and app secret obtained from
        // https://dev.filestack.com/.
        guard let security = try? Security(policy: policy, appSecret: filestackAppSecret) else {
            fatalError("Unable to instantiate Security object.")
        }

        fsClient = Client(apiKey: filestackAPIKey, security: security)
    }
}
