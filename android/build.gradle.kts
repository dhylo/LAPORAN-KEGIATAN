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

subprojects {
    if (name in setOf("file_picker", "flutter_plugin_android_lifecycle")) {
        project.plugins.withId("com.android.library") {
            val android = project.extensions.getByType(com.android.build.gradle.LibraryExtension::class.java)
            android.buildTypes.configureEach {
                it.isCheckDebugAarMetadata = false
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
