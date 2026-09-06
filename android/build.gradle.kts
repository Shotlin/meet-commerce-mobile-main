import com.android.build.gradle.LibraryExtension
import java.io.File
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            compileSdk = 34

            namespace =
                when (project.name) {
                    "flutter_windowmanager" -> "io.adaptant.labs.flutter_windowmanager"
                    "flutter_jailbreak_detection" -> "appmire.be.flutterjailbreakdetection"
                    else ->
                        namespace
                            ?: "com.bakaloo.${project.name.replace('-', '_')}"
                }

            if (
                project.name == "flutter_windowmanager" ||
                    project.name == "flutter_jailbreak_detection"
            ) {
                val manifestFile = project.file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val fixedManifestDir =
                        project.layout.buildDirectory
                            .dir("manifestFix")
                            .get()
                            .asFile
                    val fixedManifest = File(fixedManifestDir, "AndroidManifest.xml")
                    fixedManifestDir.mkdirs()
                    val sanitizedManifest =
                        manifestFile
                            .readText()
                            .replace(
                                Regex("""\spackage="[^"]+""""),
                                "",
                            )
                    fixedManifest.writeText(sanitizedManifest)
                    sourceSets.getByName("main").manifest.srcFile(fixedManifest)
                }
            }
        }
    }
}

subprojects {
    if (project.name != "app") {
        gradle.projectsEvaluated {
            val javaTarget =
                project.tasks
                    .withType<JavaCompile>()
                    .firstOrNull()
                    ?.targetCompatibility
                    ?.ifBlank { JavaVersion.VERSION_11.toString() }
                    ?: JavaVersion.VERSION_11.toString()

            val kotlinTarget =
                try {
                    JvmTarget.fromTarget(javaTarget)
                } catch (_: Throwable) {
                    JvmTarget.JVM_11
                }

            project.tasks.withType<KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(kotlinTarget)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
