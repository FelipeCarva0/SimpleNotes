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
    project.evaluationDependsOn(":app")

    // Sprint 7 (7.6) — alinha Java e Kotlin em 17 em TODOS os módulos
    // (incluindo plugins como receive_sharing_intent).
    //
    // KGP 2.2+: `kotlinOptions {}` foi removido. Usamos `compilerOptions {}`
    // (task-level), que aceita JvmTarget tipado. Docs:
    // https://kotl.in/u1r8ln
    afterEvaluate {
        // Kotlin
        if (project.plugins.hasPlugin("kotlin-android") ||
            project.plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
                .configureEach {
                    compilerOptions {
                        jvmTarget.set(
                            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
                        )
                    }
                }
        }
        // Java
        if (project.plugins.hasPlugin("com.android.library") ||
            project.plugins.hasPlugin("com.android.application")) {
            tasks.withType<JavaCompile>().configureEach {
                sourceCompatibility = "17"
                targetCompatibility = "17"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
