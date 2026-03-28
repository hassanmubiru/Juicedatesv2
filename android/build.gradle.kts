allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force build directory to ../../build/ to keep the project root clean.
rootProject.layout.buildDirectory.set(file("../../build"))

subprojects {
    project.layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(project.name))
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
