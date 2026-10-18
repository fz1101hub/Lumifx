// The effect playing, on the lock screen and in the Dynamic Island (a Live
// Activity, iOS 16.1+). The app starts, updates and ends it
// (AppDelegate.swift, LiveActivityBridge); this draws it. Part of the
// widget extension, set up as in docs/IOS_WIDGET.md. A tap opens the app;
// Stop opens it with lumifx://app/stop.
import ActivityKit
import SwiftUI
import WidgetKit

/// The same type as in AppDelegate.swift: keep the two alike.
@available(iOS 16.1, *)
struct PlayingAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var effect: String
    var room: String
    var playing: Bool
    var colors: [Int]
  }

  var stopLabel: String
}

private let stopLink = URL(string: "lumifx://app/stop")!

private func liveColor(_ argb: Int) -> Color {
  Color(
    red: Double((argb >> 16) & 0xFF) / 255,
    green: Double((argb >> 8) & 0xFF) / 255,
    blue: Double(argb & 0xFF) / 255
  )
}

@available(iOS 16.1, *)
private struct Swatches: View {
  let colors: [Int]

  var body: some View {
    HStack(spacing: 4) {
      ForEach(Array(colors.prefix(4).enumerated()), id: \.offset) { item in
        Circle().fill(liveColor(item.element)).frame(width: 12, height: 12)
      }
    }
  }
}

@available(iOS 16.1, *)
private struct StopButton: View {
  let label: String

  var body: some View {
    // Opens LumiFX, which stops and puts the lights back.
    Link(destination: stopLink) {
      Label(label, systemImage: "stop.fill")
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.18)))
    }
  }
}

@available(iOS 16.1, *)
struct PlayingLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PlayingAttributes.self) { context in
      HStack(spacing: 12) {
        Image(systemName: context.state.playing ? "lightbulb.max.fill" : "pause.circle.fill")
          .font(.title2)
          .foregroundColor(liveColor(context.state.colors.first ?? 0xFFFFD27F))
        VStack(alignment: .leading, spacing: 4) {
          Text(context.state.effect).font(.headline).lineLimit(1)
          if !context.state.room.isEmpty {
            Text(context.state.room).font(.caption).foregroundColor(.secondary)
          }
          Swatches(colors: context.state.colors)
        }
        Spacer()
        StopButton(label: context.attributes.stopLabel)
      }
      .padding(16)
      .foregroundColor(.white)
      .activityBackgroundTint(Color.black.opacity(0.85))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Swatches(colors: context.state.colors).padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Link(destination: stopLink) {
            Image(systemName: "stop.fill").font(.title3)
          }
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.state.effect).font(.headline).lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          if !context.state.room.isEmpty {
            Text(context.state.room).font(.caption).foregroundColor(.secondary)
          }
        }
      } compactLeading: {
        Image(systemName: "lightbulb.max.fill")
          .foregroundColor(liveColor(context.state.colors.first ?? 0xFFFFD27F))
      } compactTrailing: {
        Image(systemName: context.state.playing ? "waveform" : "pause.fill")
      } minimal: {
        Image(systemName: "lightbulb.max.fill")
          .foregroundColor(liveColor(context.state.colors.first ?? 0xFFFFD27F))
      }
    }
  }
}
