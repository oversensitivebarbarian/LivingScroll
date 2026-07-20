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
    // Some plugins (file_picker, just_audio) pin an older compileSdk (34) while a
    // transitive dependency (flutter_plugin_android_lifecycle) now requires
    // consumers to compile against API 36+, which fails the AAR metadata check.
    // Force every Android subproject up to compileSdk 36 to reconcile them.
    // Registered BEFORE evaluationDependsOn so the project is not yet evaluated.
    afterEvaluate {
        val androidExt = project.extensions.findByName("android") ?: return@afterEvaluate
        val setCompileSdk = androidExt.javaClass.methods.firstOrNull {
            it.name == "compileSdkVersion" &&
                it.parameterTypes.size == 1 &&
                it.parameterTypes[0] == Int::class.javaPrimitiveType
        }
        setCompileSdk?.invoke(androidExt, 36)
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
