import Foundation

var appsWithoutAXSupport: Set<String> = [
    "com.vandyke.SecureCRT",
]

var appShouldTestWithZeroWidthChar: Set<String> = [
    "com.tencent.xinWeChat",
]

func isAppWithoutAXSupport() -> Bool {
    let appInfo = ConnectionCenter.shared.currentRecordingAppContext.appInfo
    return appsWithoutAXSupport.contains(appInfo.bundleID)
}

func isAppShouldTestWithZeroWidthChar() -> Bool {
    let appInfo = ConnectionCenter.shared.currentRecordingAppContext.appInfo
    return appShouldTestWithZeroWidthChar.contains(appInfo.bundleID)
}
