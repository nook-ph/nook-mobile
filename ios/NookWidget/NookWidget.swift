import SwiftUI
import WidgetKit

// "Your saved cafes": the Want to try cafes and when they're open, the iOS
// twin of android/app/src/main/kotlin/app/nookph/SavedCafesWidgetProvider.kt.
//
// The app writes one JSON payload under `saved_cafes_v1` in the shared App
// Group (lib/features/home_widget/domain/saved_cafes_widget_data.dart): a
// list of frames, each with the time it starts. Each frame becomes one
// timeline entry, so the widget keeps time over the week without the app.

private let dataKey = "saved_cafes_v1"

/// From the extension's Info.plist, set per build configuration, so the dev
/// build reads its own group.
private var appGroup: String {
  Bundle.main.object(forInfoDictionaryKey: "NookAppGroup") as? String ?? "group.app.nookph"
}

struct Row: Hashable {
  let id: String
  let name: String
  let line: String
  let tone: String
}

struct NookEntry: TimelineEntry {
  let date: Date
  let rows: [Row]
  let openCount: Int
  /// Past the payload's `until`: ask to open Nook instead of guessing.
  let stale: Bool

  static let empty = NookEntry(date: Date(), rows: [], openCount: 0, stale: false)
  static let sample = NookEntry(
    date: Date(),
    rows: [
      Row(id: "a", name: "Abaca Baking Co.", line: "Open until 9 PM · 1.2 km", tone: "open"),
      Row(id: "b", name: "Coffee Prince", line: "Closes 6 PM", tone: "closingSoon"),
      Row(id: "c", name: "Yellow Cup", line: "Opens 7 AM", tone: "closed"),
    ],
    openCount: 2,
    stale: false
  )
}

private struct Frame {
  let start: Date
  let open: Int
  let rows: [[String]]
}

private struct Payload {
  let until: Date
  let names: [String: String]
  let frames: [Frame]

  static func read() -> Payload? {
    guard
      let json = UserDefaults(suiteName: appGroup)?.string(forKey: dataKey),
      let data = json.data(using: .utf8),
      let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    else { return nil }
    let frames = (root["frames"] as? [[String: Any]] ?? []).map { f in
      Frame(
        start: date(f["t"]),
        open: (f["o"] as? NSNumber)?.intValue ?? 0,
        rows: (f["rows"] as? [[Any]] ?? []).map { $0.map { "\($0)" } }
      )
    }
    return Payload(
      until: date(root["until"]),
      names: root["names"] as? [String: String] ?? [:],
      frames: frames
    )
  }

  private static func date(_ millis: Any?) -> Date {
    Date(timeIntervalSince1970: ((millis as? NSNumber)?.doubleValue ?? 0) / 1000)
  }

  func entry(_ frame: Frame, at date: Date) -> NookEntry {
    let rows = frame.rows.compactMap { r -> Row? in
      guard r.count >= 3, let name = names[r[0]] else { return nil }
      return Row(id: r[0], name: name, line: r[1], tone: r[2])
    }
    return NookEntry(date: date, rows: rows, openCount: frame.open, stale: false)
  }
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> NookEntry { .sample }

  func getSnapshot(in context: Context, completion: @escaping (NookEntry) -> Void) {
    if context.isPreview && Payload.read() == nil {
      completion(.sample)
    } else {
      completion(timeline(now: Date()).entries.first ?? .empty)
    }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<NookEntry>) -> Void) {
    completion(timeline(now: Date()))
  }

  private func timeline(now: Date) -> Timeline<NookEntry> {
    guard let payload = Payload.read(), !payload.names.isEmpty, !payload.frames.isEmpty else {
      return Timeline(entries: [.empty], policy: .never)
    }
    let stale = NookEntry(date: payload.until, rows: [], openCount: 0, stale: true)
    if now >= payload.until { return Timeline(entries: [stale], policy: .never) }

    // The last frame that has started (the first if none has), then every
    // later one, then the stale entry at `until`. The app writes a new
    // payload and reloads whenever its data changes.
    let current = payload.frames.lastIndex { $0.start <= now } ?? 0
    var entries = [payload.entry(payload.frames[current], at: now)]
    for frame in payload.frames[(current + 1)...] {
      entries.append(payload.entry(frame, at: frame.start))
    }
    entries.append(stale)
    return Timeline(entries: entries, policy: .never)
  }
}

private enum Palette {
  static let ink = Color(red: 0x0A / 255, green: 0x0F / 255, blue: 0x0D / 255)
  static let muted = Color(red: 0x76 / 255, green: 0x75 / 255, blue: 0x74 / 255)
  static let brand = Color(red: 0x34 / 255, green: 0x4E / 255, blue: 0x41 / 255)
  static let open = Color(red: 0x0F / 255, green: 0x89 / 255, blue: 0x3E / 255)
  static let soon = Color(red: 0xE0 / 255, green: 0xAB / 255, blue: 0x38 / 255)
  static let closed = Color(red: 0xC4 / 255, green: 0xC4 / 255, blue: 0xC4 / 255)

  static func tone(_ tone: String) -> Color {
    switch tone {
    case "open": return open
    case "closingSoon": return soon
    default: return closed
    }
  }
}

/// A `nook://` link the app routes (lib/features/home_widget/presentation/
/// widget_links.dart). `homeWidget` lets the home_widget plugin report the
/// tap to Dart.
private func link(_ path: String) -> URL {
  URL(string: "nook://\(path)&homeWidget")!
}

struct NookWidgetView: View {
  var entry: NookEntry
  @Environment(\.widgetFamily) private var family

  private var small: Bool { family == .systemSmall }

  /// "2 open · 3:10 PM": a count with the time it was drawn, in Manila like
  /// every time on the rows.
  private var count: String? {
    guard !entry.rows.isEmpty else { return nil }
    let format = DateFormatter()
    format.timeZone = TimeZone(identifier: "Asia/Manila")
    format.timeStyle = .short
    let open = entry.openCount == 0 ? "None open" : "\(entry.openCount) open"
    return "\(open) · \(format.string(from: entry.date))"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Link(destination: link("saved?via=widget")) {
        HStack(spacing: 6) {
          Text(small ? "Saved cafes" : "Your saved cafes")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.brand)
            .lineLimit(1)
          Spacer(minLength: 0)
          if let count, !small {
            Text(count).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
          }
        }
      }
      if entry.rows.isEmpty {
        Spacer(minLength: 0)
        emptyState
        Spacer(minLength: 0)
      } else {
        ForEach(entry.rows.prefix(small ? 1 : 3), id: \.self) { row in
          Link(destination: cafeLink(row.id)) { rowView(row) }
        }
        Spacer(minLength: 0)
        if let count, small {
          Text(count).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .widgetURL(link("saved?via=widget"))
  }

  private func cafeLink(_ id: String) -> URL {
    let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
    return link("cafe/\(encoded)?via=widget")
  }

  private func rowView(_ row: Row) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Circle().fill(Palette.tone(row.tone)).frame(width: 7, height: 7)
      VStack(alignment: .leading, spacing: 1) {
        Text(row.name)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(Palette.ink)
          .lineLimit(1)
        Text(row.line)
          .font(.system(size: 12))
          .foregroundStyle(Palette.muted)
          .lineLimit(small ? 2 : 1)
      }
    }
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder private var emptyState: some View {
    if entry.stale {
      Link(destination: link("saved?via=widget&tap=stale")) {
        Text("Open Nook to update your cafes")
          .font(.system(size: 13))
          .foregroundStyle(Palette.muted)
      }
    } else {
      Link(destination: link("home?via=widget")) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Save cafes to see them here")
            .font(.system(size: 13))
            .foregroundStyle(Palette.muted)
          Text("Find a cafe")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.brand)
        }
      }
    }
  }
}

struct NookWidget: Widget {
  let kind = "NookWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      if #available(iOS 17.0, *) {
        // iOS turns this background into glass in the Clear and Tinted
        // home screen looks (iOS 26).
        NookWidgetView(entry: entry).containerBackground(Color.white, for: .widget)
      } else {
        NookWidgetView(entry: entry).padding().background(Color.white)
      }
    }
    .configurationDisplayName("Your saved cafes")
    .description("Your Want to try cafes and when they're open")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct NookWidgetBundle: WidgetBundle {
  var body: some Widget { NookWidget() }
}
