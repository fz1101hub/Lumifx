// The iOS home-screen widget of the favourite effects. Not part of the
// Xcode project yet: adding it needs an App Group on your Apple account
// (see docs/IOS_WIDGET.md). The app already writes the widget's content
// to that group (AppDelegate.swift, WidgetData).
import SwiftUI
import WidgetKit

private let appGroup = "group.com.lumifx.lumifx"

struct WidgetEffect: Decodable, Identifiable {
  let id: String
  let name: String
  let colors: [Int]
  let link: String
}

struct WidgetContent: Decodable {
  let title: String
  let empty: String
  let effects: [WidgetEffect]

  static let placeholder = WidgetContent(
    title: "Favourites",
    empty: "Star effects in LumiFX to see them here.",
    effects: []
  )

  static func load() -> WidgetContent {
    guard
      let defaults = UserDefaults(suiteName: appGroup),
      let json = defaults.string(forKey: "content"),
      let data = json.data(using: .utf8),
      let content = try? JSONDecoder().decode(WidgetContent.self, from: data)
    else { return placeholder }
    return content
  }
}

struct Entry: TimelineEntry {
  let date: Date
  let content: WidgetContent
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> Entry {
    Entry(date: Date(), content: .placeholder)
  }

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    completion(Entry(date: Date(), content: .load()))
  }

  // The app reloads the timeline whenever the favourites change.
  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    completion(Timeline(entries: [Entry(date: Date(), content: .load())], policy: .never))
  }
}

private extension Color {
  init(argb: Int) {
    self.init(
      .sRGB,
      red: Double((argb >> 16) & 0xFF) / 255,
      green: Double((argb >> 8) & 0xFF) / 255,
      blue: Double(argb & 0xFF) / 255
    )
  }
}

struct Tile: View {
  let effect: WidgetEffect

  var body: some View {
    Link(destination: URL(string: effect.link)!) {
      ZStack(alignment: .bottomLeading) {
        LinearGradient(
          colors: effect.colors.isEmpty
            ? [.gray, .gray] : effect.colors.map { Color(argb: $0) },
          startPoint: .topLeading, endPoint: .bottomTrailing)
        Text(effect.name)
          .font(.caption.bold())
          .foregroundColor(.white)
          .shadow(radius: 3)
          .lineLimit(2)
          .padding(8)
      }
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }
}

struct FavoritesView: View {
  let content: WidgetContent

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(content.title).font(.caption.bold())
      if content.effects.isEmpty {
        Spacer()
        Text(content.empty).font(.caption).foregroundColor(.secondary)
        Spacer()
      } else {
        let effects = Array(content.effects.prefix(4))
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
          ForEach(effects) { Tile(effect: $0).frame(height: 52) }
        }
      }
    }
    .padding(12)
  }
}

struct LumiFXWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "LumiFXFavorites", provider: Provider()) { entry in
      if #available(iOS 17.0, *) {
        FavoritesView(content: entry.content)
          .containerBackground(.black, for: .widget)
      } else {
        FavoritesView(content: entry.content).background(Color.black)
      }
    }
    .configurationDisplayName("LumiFX")
    .description("Your favourite LumiFX effects, one tap away.")
    .supportedFamilies([.systemMedium])
  }
}

/// The favourites widget and, from iOS 16.1, the effect playing on the
/// lock screen (PlayingLiveActivity.swift).
@main
struct LumiFXWidgets: WidgetBundle {
  var body: some Widget {
    LumiFXWidget()
    if #available(iOS 16.1, *) {
      PlayingLiveActivity()
    }
  }
}
