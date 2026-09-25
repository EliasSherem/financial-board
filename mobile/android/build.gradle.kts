allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.glance") {
                useVersion("1.1.1")
                because("home_widget 0.8.1 declares glance-appwidget as 1.+, which currently resolves to an alpha requiring Android SDK 37 and AGP 9.1.")
            }
        }
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

// home_widget 0.8.1 targets Java 8 while its resolved WorkManager requires 11.
// Align this plugin with the app toolchain; do not override Play Billing dependencies.
subprojects {
    if (name == "home_widget") {
        afterEvaluate {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_11
                    targetCompatibility = JavaVersion.VERSION_11
                }
            }
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                kotlinOptions.jvmTarget = "11"
            }
        }
    }
}
