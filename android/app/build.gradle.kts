import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ── Leitura do key.properties (Kotlin DSL — Build 113) ───────────────────────
// Validação defensiva: falha imediatamente com mensagem clara se o arquivo ou
// qualquer propriedade estiver ausente — em vez de NullPointerException genérico
// em ':app:signReleaseBundle' (BundleTool não recebe null sem avisar).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (!keystorePropertiesFile.exists()) {
    throw GradleException(
        "\n\n" +
        "╔══════════════════════════════════════════════════════════════╗\n" +
        "║  ERRO CRÍTICO DE ASSINATURA — key.properties não encontrado  ║\n" +
        "╚══════════════════════════════════════════════════════════════╝\n" +
        "Arquivo esperado em: ${keystorePropertiesFile.absolutePath}\n" +
        "Crie o arquivo 'key.properties' na pasta /android com:\n" +
        "  storePassword=<senha>\n" +
        "  keyPassword=<senha>\n" +
        "  keyAlias=<alias>\n" +
        "  storeFile=../upload-keystore.jks\n"
    )
} else {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.medcasespro.med"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            // Lê cada propriedade individualmente e valida antes de atribuir.
            // Qualquer null gera GradleException com o nome exato da chave faltante —
            // impede NullPointerException silencioso no BundleTool durante signReleaseBundle.
            val alias       = keystoreProperties.getProperty("keyAlias")
            val keyPass     = keystoreProperties.getProperty("keyPassword")
            val storePass   = keystoreProperties.getProperty("storePassword")
            val storeFilePath = keystoreProperties.getProperty("storeFile")

            val missing = listOfNotNull(
                if (alias         == null) "keyAlias"       else null,
                if (keyPass       == null) "keyPassword"    else null,
                if (storePass     == null) "storePassword"  else null,
                if (storeFilePath == null) "storeFile"      else null,
            )
            if (missing.isNotEmpty()) {
                throw GradleException(
                    "\n\n" +
                    "╔══════════════════════════════════════════════════════════════╗\n" +
                    "║  ERRO CRÍTICO DE ASSINATURA — propriedades ausentes          ║\n" +
                    "╚══════════════════════════════════════════════════════════════╝\n" +
                    "As seguintes chaves estão AUSENTES ou com nome errado em key.properties:\n" +
                    "  ${missing.joinToString(", ")}\n" +
                    "Arquivo lido: ${keystorePropertiesFile.absolutePath}\n"
                )
            }

            keyAlias      = alias
            keyPassword   = keyPass
            storePassword = storePass
            storeFile     = file(storeFilePath!!)
        }
    }

    defaultConfig {
        applicationId = "com.medcasespro.med"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Build 104 — signingConfig aponta SEMPRE para release. Nunca debug key.
            // Build 113 — validação defensiva garante que todas as props chegam
            // não-nulas ao BundleTool (resolve NullPointerException em signReleaseBundle).
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
