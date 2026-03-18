import Combine
import Foundation
import SwiftUI

class ContentModel: ObservableObject {
  static let shared = ContentModel()

  @Published var text: String = ""
  @Published var history: [String] = []

  private var cancellables = Set<AnyCancellable>()

  private init() {
    $text
      .debounce(for: .seconds(15), scheduler: RunLoop.main)
      .removeDuplicates()
      .sink { [weak self] newText in
        self?.addSnapshot(newText)
      }
      .store(in: &cancellables)
  }

  func addSnapshot(_ snapshot: String) {
    guard !snapshot.isEmpty else { return }

    // Avoid adding the same snapshot if it's identical to the most recent one
    if let first = history.first, first == snapshot {
      return
    }

    withAnimation {
      history.insert(snapshot, at: 0)
      if history.count > 5 {
        history.removeLast()
      }
    }
  }

  func restore(_ snapshot: String) {
    self.text = snapshot
  }
}
