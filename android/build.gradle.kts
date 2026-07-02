buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // BUILD 283: atualizado 4.4.2 → 4.5.0 (última versão estável do Google Services plugin).
        // 4.5.0 adiciona suporte a Android Gradle Plugin 8.x e corrige warnings de
        // configuração de SHA fingerprint no firebase.google.com console.
        classpath("com.google.gms:google-services:4.5.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
