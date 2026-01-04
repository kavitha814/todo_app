import com.android.build.gradle.LibraryExtension
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
    
    plugins.withId("com.android.library") {
        if (name == "isar_flutter_libs") {
            extensions.configure<LibraryExtension>("android") {
                namespace = "dev.isar.isar_flutter_libs"
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

