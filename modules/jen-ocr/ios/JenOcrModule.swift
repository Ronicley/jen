import ExpoModulesCore
import Vision
import ImageIO

public class JenOcrModule: Module {
  public func definition() -> ModuleDefinition {
    Name("JenOcr")
    AsyncFunction("recognize") { (path: String, promise: Promise) in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          guard let url = URL(string: path), url.isFileURL else {
            promise.reject("OCR_IMAGE", "Imagem local inválida.")
            return
          }
          let request = VNRecognizeTextRequest()
          request.recognitionLevel = .accurate
          request.recognitionLanguages = ["pt-BR", "en-US"]
          request.usesLanguageCorrection = true
          try VNImageRequestHandler(url: url).perform([request])
          let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
          promise.resolve(lines.joined(separator: "\n"))
        } catch {
          promise.reject("OCR_READ", "Não foi possível ler a imagem.", error)
        }
      }
    }
  }
}
