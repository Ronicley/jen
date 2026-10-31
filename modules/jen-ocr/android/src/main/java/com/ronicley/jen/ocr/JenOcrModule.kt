package com.ronicley.jen.ocr

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class JenOcrModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("JenOcr")

    AsyncFunction("recognize") { path: String, promise: Promise ->
      val context = appContext.reactContext
      val uri = Uri.parse(path)
      if (context == null || uri.scheme !in listOf("file", "content")) {
        promise.reject("OCR_IMAGE", "Imagem local inválida.", null)
        return@AsyncFunction
      }
      val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
      try {
        val image = InputImage.fromFilePath(context, uri)
        recognizer.process(image)
          .addOnSuccessListener { result ->
            val lines = result.textBlocks.flatMap { it.lines }.sortedWith(
              compareBy({ it.boundingBox?.top ?: 0 }, { it.boundingBox?.left ?: 0 })
            )
            promise.resolve(lines.joinToString("\n") { it.text })
          }
          .addOnFailureListener { error -> promise.reject("OCR_READ", "Não foi possível ler a imagem.", error) }
          .addOnCompleteListener { recognizer.close() }
      } catch (error: Exception) {
        recognizer.close()
        promise.reject("OCR_IMAGE", "Não foi possível abrir a imagem.", error)
      }
    }
  }
}
