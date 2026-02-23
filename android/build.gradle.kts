allprojects {
    repositories {
        google()
        mavenCentral()
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

subprojects {
    project.pluginManager.withPlugin("com.android.library") {
        val extension = project.extensions.findByName("android")
        if (extension != null) {
            try {
                val namespaceMethod = extension.javaClass.getMethod("getNamespace")
                val currentNamespace = namespaceMethod.invoke(extension) as? String
                if (currentNamespace.isNullOrBlank()) {
                    val setNamespaceMethod = extension.javaClass.getMethod("setNamespace", String::class.java)
                    val packageGroup = project.group.toString()
                    val name = project.name.replace("-", "_")
                    val newNamespace = if (packageGroup.isNotBlank() && packageGroup != "unspecified") packageGroup else "com.example.$name"
                    setNamespaceMethod.invoke(extension, newNamespace)
                }
            } catch (e: Exception) {
                // Ignore
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
