// START: ADD THIS BLOCK AT THE TOP
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // This is the classpath that allows the App-level file to use the plugin
        // The version here (4.4.2) matches the latest stable release
        classpath("com.google.gms:google-services:4.4.2")
    }
}
// END: ADD THIS BLOCK

// --- BELOW IS YOUR EXISTING CODE (KEEP THIS) ---

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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