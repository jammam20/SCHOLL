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

// Kotlin 2.4.0 added a stricter check that rejects an implicit reference to a
// type reached only through an *indirect* dependency (see
// https://kotlinlang.org/docs/whatsnew24.html) — several Flutter Firebase
// plugins (firebase_auth among them) compile Kotlin sources that reach
// org.checkerframework.checker.initialization.qual.UnknownInitialization
// this way, without depending on checker-qual directly themselves, which
// used to be silently tolerated and now fails with "... is inaccessible.
// Check the module classpath for missing or conflicting dependencies."
// Kotlin's own documented fix is "add the missing direct dependency" — since
// each Flutter plugin is its own Gradle subproject of this same build, that
// has to happen here (subprojects{}), not in this app's own app/build.gradle.kts,
// which has no effect on a *different* subproject's compilation classpath.
// Different Flutter plugin subprojects reach evaluation at different times
// relative to this block, so neither "always defer via afterEvaluate" nor
// "always add directly, right now" is safe for all of them — check whether
// this specific subproject has already finished evaluating and pick
// whichever of the two is actually safe for it.
subprojects {
    val addCheckerQual = Action<Project> {
        if (configurations.findByName("implementation") != null) {
            dependencies.add("implementation", "org.checkerframework:checker-qual:3.43.0")
        }
    }
    if (state.executed) {
        addCheckerQual.execute(this)
    } else {
        afterEvaluate(addCheckerQual)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
