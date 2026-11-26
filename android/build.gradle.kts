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
    // Only relocate buildDir onto the root project's drive if the subproject lives on the same drive root
    // (e.g., :app on D:\). Relocating C:\ Pub-cache plugins onto D:\ causes Kotlin compiler root-path crashes on Windows.
    val rootDrive = rootProject.projectDir.toPath().root
    val subDrive = project.projectDir.toPath().root
    if (rootDrive == subDrive) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
