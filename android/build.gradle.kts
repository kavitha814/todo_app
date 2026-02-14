import com.android.build.gradle.LibraryExtension
import com.android.build.gradle.BaseExtension
import org.gradle.api.tasks.Delete

rootProject.layout.buildDirectory.set(file("${rootDir}/../build"))

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(project.name))
    
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            android.compileSdkVersion(35)
            android.defaultConfig {
                targetSdkVersion(35)
            }
        }
    }

    plugins.withId("com.android.library") {
        if (name == "isar_flutter_libs") {
            extensions.configure<LibraryExtension>("android") {
                namespace = "dev.isar.isar_flutter_libs"
            }
        }
        if (name == "device_apps") {
            extensions.configure<LibraryExtension>("android") {
                namespace = "fr.g123k.deviceapps"
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}

