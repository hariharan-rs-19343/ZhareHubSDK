import Testing
@testable import ZhareHubSDK

@Test func parsesMinSdkFromAapt2Badging() {
    let badging = """
    package: name='com.zoho.admin.keyregister' versionCode='4' versionName='1.0.3' platformBuildVersionName='14' platformBuildVersionCode='34' compileSdkVersion='34' compileSdkVersionCodename='14'
    minSdkVersion:'24'
    targetSdkVersion:'34'
    uses-permission: name='android.permission.MANAGE_ACCOUNTS' maxSdkVersion='22'
    """
    let properties = DefaultAPKBadgingParser().loadProperties(from: badging, fileName: "app.apk")
    #expect(properties.minSDK == "24")
    #expect(properties.targetSDK == "34")
    #expect(properties.versionCode == "4")
}

@Test func parsesMinSdkFromLegacyAaptBadging() {
    let badging = """
    package: name='com.example' versionCode='1' versionName='1.0'
    sdkVersion:'21'
    targetSdkVersion:'30'
    """
    let properties = DefaultAPKBadgingParser().loadProperties(from: badging, fileName: "app.apk")
    #expect(properties.minSDK == "21")
    #expect(properties.targetSDK == "30")
}
