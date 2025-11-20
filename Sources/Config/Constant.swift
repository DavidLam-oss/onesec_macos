import Foundation

let terminalAppsWithoutAXSupport: Set<String> = [
    "com.vandyke.SecureCRT",
]

let appShouldTestWithZeroWidthChar: Set<String> = [
    "com.tencent.xinWeChat",
]

func isAppWithoutAXSupport() -> Bool {
    let appInfo = ConnectionCenter.shared.currentRecordingAppContext.appInfo
    return terminalAppsWithoutAXSupport.contains(appInfo.bundleID)
}

func isAppShouldTestWithZeroWidthChar() -> Bool {
    let appInfo = ConnectionCenter.shared.currentRecordingAppContext.appInfo
    return appShouldTestWithZeroWidthChar.contains(appInfo.bundleID)
}
