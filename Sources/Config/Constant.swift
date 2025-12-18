import Foundation

var appsWithoutAXSupport: Set<String> = [
    "com.vandyke.SecureCRT",
]

var appShouldTestWithZeroWidthChar: Set<String> = [
    "com.tencent.xinWeChat",
]

// native
var appWithAXReturnErrorSelectedText: Set<String> = [
    "com.todesktop.230313mzl4w4u92",
]

func isAppWithoutAXSupport() -> Bool {
    let appInfo = ConnectionCenter.shared.currentRecordingAppContext.appInfo
    return appsWithoutAXSupport.contains(appInfo.bundleID)
}

func isAppShouldTestWithZeroWidthChar() -> Bool {
    let appInfo = ConnectionCenter.shared.currentRecordingAppContext.appInfo
    return appShouldTestWithZeroWidthChar.contains(appInfo.bundleID)
}

func isAppWithAXReturnErrorSelectedText(bundleID: String) -> Bool {
    return appWithAXReturnErrorSelectedText.contains(bundleID)
}
