import Foundation

let terminalAppsWithoutAXSupport: Set<String> = [
    "com.termius-dmg.mac",
    "org.tabby",
    "com.vandyke.SecureCRT",
]

func isTerminalAppWithoutAXSupport(_ appInfo: AppInfo) -> Bool {
    terminalAppsWithoutAXSupport.contains(appInfo.bundleID)
}
