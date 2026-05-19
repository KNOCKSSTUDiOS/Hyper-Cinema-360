
// ── KNOCKSSTUDiOS • NEBULA • Signing Config (autogen) ─────────
import java.util.Properties
import java.io.FileInputStream

val keystorePropsFile = rootProject.file("keystore.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) load(FileInputStream(keystorePropsFile))
}
fun sval(key: String, env: String): String? =
    System.getenv(env) ?: keystoreProps.getProperty(key)

android {
    signingConfigs {
        create("release") {
            val sf = sval("storeFile", "NEBULA_STORE_FILE")
            val sp = sval("storePassword", "NEBULA_STORE_PASS")
            val ka = sval("keyAlias", "NEBULA_KEY_ALIAS")
            val kp = sval("keyPassword", "NEBULA_KEY_PASS")
            if (sf != null && sp != null && ka != null && kp != null) {
                storeFile = rootProject.file(sf)
                storePassword = sp
                keyAlias = ka
                keyPassword = kp
                enableV1Signing = false
                enableV2Signing = true
                enableV3Signing = true
                enableV4Signing = true
            } else {
                println("⚠️  NEBULA signing missing — release will be UNSIGNED")
            }
        }
    }
    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
