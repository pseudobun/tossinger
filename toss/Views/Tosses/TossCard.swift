//
//  TossCard.swift
//  toss
//
//  Created by Urban Vidovič on 7. 10. 25.
//

import MarkdownUI
import SwiftUI

struct TossCard: View {
  let toss: Toss

  @State private var isHovered = false

  var body: some View {
    Group {
      if toss.type == .link {
        linkCard
      } else {
        textCard
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    #if os(macOS)
      .onHover { hovering in
        isHovered = hovering
      }
      .shadow(
        color: .black.opacity(isHovered ? 0.08 : 0.03),
        radius: isHovered ? 4 : 2,
        y: 1
      )
      .scaleEffect(isHovered ? 1.005 : 1.0)
    #endif
  }

  private var linkCard: some View {
    ZStack(alignment: .bottomLeading) {
      Color.clear
        #if os(macOS)
          .aspectRatio(0.9, contentMode: .fit)
        #else
          .aspectRatio(1.2, contentMode: .fit)
        #endif
        .overlay {
          LinkCardBody(
            toss: toss,
            platformBackgroundColor: platformBackgroundColor
          )
          .equatable()
        }

      TopLeftXIcon(shouldShow: shouldShowTopLeftIcon, isPost: toss.platformType == .xPost)
        .equatable()
      PlatformBadgeView(
        platformType: toss.platformType,
        metadataTitle: toss.metadataTitle,
        metadataAuthor: toss.metadataAuthor,
        content: toss.content
      )
      .equatable()
    }
  }

  private var textCard: some View {
    Color.clear
      #if os(macOS)
        .aspectRatio(0.9, contentMode: .fit)
      #else
        .aspectRatio(1.2, contentMode: .fit)
      #endif
      .overlay(alignment: .topLeading) {
        TextCardBody(
          previewText: previewText,
          markdownSource: toss.content,
          createdAt: toss.createdAt,
          useLightweightText: FeatureFlags.useLightweightCardText
        )
        .equatable()
      }
      .background(cardBackgroundColor)
  }

  private var previewText: String {
    if let existing = toss.previewPlainText, !existing.isEmpty {
      return existing
    }

    return CardPreviewText.makePreview(from: toss.content)
  }

  private var shouldShowTopLeftIcon: Bool {
    switch toss.platformType {
    case .xProfile, .xPost:
      return true
    default:
      return false
    }
  }

  private var platformBackgroundColor: Color {
    switch toss.platformType {
    case .github:
      return Color(red: 0.08, green: 0.08, blue: 0.08)
    case .youtube:
      return Color(red: 0.90, green: 0.0, blue: 0.0)
    case .xProfile, .xPost:
      return Color(red: 0.0, green: 0.0, blue: 0.0)
    case .genericWebsite, nil:
      return Color(red: 0.20, green: 0.22, blue: 0.25)
    }
  }

  private var cardBackgroundColor: Color {
    #if os(macOS)
      return Color(nsColor: .controlBackgroundColor)
    #else
      return Color(uiColor: .secondarySystemBackground)
    #endif
  }
}

private struct LinkCardBody: View, Equatable {
  let toss: Toss
  let platformBackgroundColor: Color

  var body: some View {
    switch toss.platformType {
    case .xProfile:
      LinearGradient(
        colors: [
          Color(red: 0.1, green: 0.1, blue: 0.1),
          Color(red: 0.15, green: 0.15, blue: 0.15),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

    case .xPost:
      ZStack {
        LinearGradient(
          colors: [
            Color(red: 0.1, green: 0.1, blue: 0.1),
            Color(red: 0.15, green: 0.15, blue: 0.15),
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )

        VStack(alignment: .leading, spacing: 0) {
          Color.clear
            .frame(height: 48)

          if let description = toss.metadataDescription {
            Text(description)
              #if os(iOS)
                .font(.caption)
              #else
                .font(.body)
              #endif
              .foregroundStyle(.white)
              #if os(iOS)
                .lineLimit(22)
              #else
                .lineLimit(12)
              #endif
              .multilineTextAlignment(.leading)
              .padding(.horizontal, 16)
          }

          Spacer(minLength: 0)
        }
        .padding(.bottom, 56)
      }

    case .youtube, .github, .genericWebsite, nil:
      Group {
        if FeatureFlags.useThumbnailPipeline {
          TossCardThumbnailView(toss: toss)
        } else if let fallback = legacyImage {
          fallback
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          PlaceholderImage(platformBackgroundColor: platformBackgroundColor)
        }
      }
    }
  }

  private var legacyImage: Image? {
    let data = toss.thumbnailDataOptimized ?? toss.imageData
    guard let data else { return nil }

    #if os(macOS)
      guard let nsImage = NSImage(data: data) else { return nil }
      return Image(nsImage: nsImage)
    #else
      guard let uiImage = UIImage(data: data) else { return nil }
      return Image(uiImage: uiImage)
    #endif
  }

  static func == (lhs: LinkCardBody, rhs: LinkCardBody) -> Bool {
    lhs.toss.persistentModelID == rhs.toss.persistentModelID
      && lhs.toss.metadataDescription == rhs.toss.metadataDescription
      && lhs.toss.metadataTitle == rhs.toss.metadataTitle
      && lhs.toss.metadataAuthor == rhs.toss.metadataAuthor
      && lhs.toss.platformType == rhs.toss.platformType
      && lhs.toss.imageData?.count == rhs.toss.imageData?.count
      && lhs.toss.thumbnailDataOptimized?.count == rhs.toss.thumbnailDataOptimized?.count
  }
}

private struct PlaceholderImage: View, Equatable {
  let platformBackgroundColor: Color

  var body: some View {
    Rectangle()
      .fill(platformBackgroundColor)
      .overlay {
        VStack(spacing: 10) {
          Image(systemName: "exclamationmark.circle")
            .font(.system(size: 32))
            .foregroundStyle(.white.opacity(0.45))

          Text("Couldn't load image")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
        }
      }
  }
}

private struct TopLeftXIcon: View, Equatable {
  let shouldShow: Bool
  let isPost: Bool

  var body: some View {
    Group {
      if shouldShow {
        VStack {
          HStack {
            Image("x-logo")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 16, height: 16)
              .opacity(isPost ? 0.5 : 0.35)
            Spacer()
          }
          Spacer()
        }
        .padding(16)
      }
    }
  }
}

private struct PlatformBadgeView: View, Equatable {
  let platformType: PlatformType?
  let metadataTitle: String?
  let metadataAuthor: String?
  let content: String

  var body: some View {
    Group {
      switch platformType {
      case .github:
        LabelView(icon: AnyView(
          Image("github-mark-white")
            .resizable()
            .frame(width: 12, height: 12)
        ), title: githubRepoName)

      case .youtube:
        LabelView(icon: AnyView(
          Image("yt-logo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16)
        ), title: metadataTitle ?? "YouTube")

      case .xProfile, .xPost:
        LabelView(icon: AnyView(
          Image("x-logo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 10, height: 10)
        ), title: formattedXUsername)

      case .genericWebsite, nil:
        LabelView(icon: AnyView(
          Image(systemName: "safari")
            .font(.caption)
        ), title: metadataTitle ?? extractDomain(from: content))
      }
    }
  }

  private var githubRepoName: String {
    guard let url = URL(string: content) else {
      return "GitHub"
    }

    let pathComponents = url.pathComponents.filter { $0 != "/" }
    if pathComponents.count >= 2 {
      return "\(pathComponents[0])/\(pathComponents[1])"
    }
    return pathComponents.first ?? "GitHub"
  }

  private var formattedXUsername: String {
    guard let metadataAuthor else { return "X" }
    return metadataAuthor.hasPrefix("@") ? metadataAuthor : "@\(metadataAuthor)"
  }

  private func extractDomain(from urlString: String) -> String {
    guard let url = URL(string: urlString), let host = url.host else {
      return urlString
    }

    return host.replacingOccurrences(
      of: "^www\\.",
      with: "",
      options: .regularExpression
    )
  }
}

private struct LabelView: View, Equatable {
  let icon: AnyView
  let title: String

  var body: some View {
    HStack(spacing: 6) {
      icon
      Text(title)
        .font(.caption)
        .fontWeight(.medium)
        .lineLimit(1)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(.black.opacity(0.72))
    .cornerRadius(8)
    .padding(12)
  }

  static func == (lhs: LabelView, rhs: LabelView) -> Bool {
    lhs.title == rhs.title
  }
}

private struct TextCardBody: View, Equatable {
  let previewText: String
  let markdownSource: String
  let createdAt: Date
  let useLightweightText: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if useLightweightText {
        Text(previewText)
          .font(.body)
          .lineLimit(4)
          .truncationMode(.tail)
          .multilineTextAlignment(.leading)
      } else {
        Markdown(markdownSource)
          .lineLimit(4)
          .truncationMode(.tail)
          .multilineTextAlignment(.leading)
      }

      Spacer(minLength: 0)

      HStack {
        Image(systemName: "doc.text")
          .font(.caption)
          .foregroundStyle(.secondary)

        Spacer()

        Text(createdAt, style: .relative)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(12)
  }

  static func == (lhs: TextCardBody, rhs: TextCardBody) -> Bool {
    lhs.previewText == rhs.previewText
      && lhs.markdownSource == rhs.markdownSource
      && lhs.createdAt == rhs.createdAt
      && lhs.useLightweightText == rhs.useLightweightText
  }
}
