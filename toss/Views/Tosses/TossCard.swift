//
//  TossCard.swift
//  toss
//
//  Created by Urban Vidovič on 7. 10. 25.
//

import MarkdownUI
import SwiftData
import SwiftUI

struct TossCard: View {
  let toss: Toss
  @Environment(\.modelContext) private var modelContext
  @State private var isHovered = false

  var body: some View {
    if toss.type == .link {
      // Link card
      ZStack(alignment: .bottomLeading) {
        Color.clear
          .aspectRatio(linkAspectRatio, contentMode: .fit)
          .overlay {
            cardContent
          }
          .clipped()
          .cornerRadius(12)

        // Top-left icon (shown only for certain platforms)
        topLeftIcon

        // Platform-specific badge
        platformBadge
      }
      .contentShape(Rectangle())
      #if os(macOS)
        .onHover { hovering in
          withAnimation(.easeInOut(duration: 0.2)) {
            isHovered = hovering
          }
        }
        .shadow(
          color: .black.opacity(isHovered ? 0.15 : 0.05),
          radius: isHovered ? 8 : 4,
          y: 2
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
      #endif
    } else {
      // Text card
      Color.clear
        .aspectRatio(textAspectRatio, contentMode: .fit)
        .overlay(alignment: .topLeading) {
          VStack(alignment: .leading, spacing: 8) {
            Markdown(toss.content)
              .lineLimit(4)
              .truncationMode(.tail)
              .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            HStack {
              Image(systemName: "doc.text")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer()
              Text(toss.createdAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(12)
        }
        .background(cardBackground)
        .cornerRadius(12)
        .clipped()
        .contentShape(Rectangle())
        #if os(macOS)
          .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
              isHovered = hovering
            }
          }
          .shadow(
            color: .black.opacity(isHovered ? 0.15 : 0.05),
            radius: isHovered ? 8 : 4,
            y: 2
          )
          .scaleEffect(isHovered ? 1.02 : 1.0)
        #endif
    }
  }

  // MARK: - Aspect Ratios

  private var linkAspectRatio: CGFloat {
    return 5.0 / 4.0  // 1.25 - Consistent landscape ratio
  }

  private var textAspectRatio: CGFloat {
    return 5.0 / 4.0  // 1.25 - Consistent landscape ratio
  }

  // MARK: - Card Content

  @ViewBuilder
  private var cardContent: some View {
    switch toss.platformType {
    case .xProfile:
      xProfileContent
    case .xPost:
      xPostContent
    case .youtube, .github, .genericWebsite, nil:
      imageOrPlaceholderContent
    }
  }

  // MARK: - X Profile Content

  private var xProfileContent: some View {
    ZStack {
      // Dark grey gradient background
      LinearGradient(
        gradient: Gradient(colors: [
          Color(red: 0.1, green: 0.1, blue: 0.1),
          Color(red: 0.15, green: 0.15, blue: 0.15),
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
  }

  // MARK: - X Post Content

  private var xPostContent: some View {
    ZStack {
      // Dark grey gradient background
      LinearGradient(
        gradient: Gradient(colors: [
          Color(red: 0.1, green: 0.1, blue: 0.1),
          Color(red: 0.15, green: 0.15, blue: 0.15),
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      VStack(alignment: .leading, spacing: 0) {
        // Space for top-left X icon
        Color.clear
          .frame(height: 64)

        // Tweet content
        if let description = toss.metadataDescription {
          Text(description)
            .font(.body)
            .foregroundStyle(.white)
            .lineLimit(12)
            .multilineTextAlignment(.leading)
            .padding(.leading, 16)
            .padding(.trailing, 16)
        }

        Spacer()
      }
      .padding(.bottom, 60)  // Space for badge
    }
  }

  // MARK: - Image or Placeholder Content

  private var imageOrPlaceholderContent: some View {
    Group {
      if let imageData = toss.imageData,
        let image = platformImage(from: imageData)
      {
        // YouTube thumbnails and other images fill the card
        image
          .resizable()
          .scaledToFill()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        // Show "Couldn't load image" fallback
        failedImagePlaceholder
      }
    }
  }

  private var failedImagePlaceholder: some View {
    Rectangle()
      .fill(platformBackgroundColor)
      .overlay {
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.circle")
            .font(.system(size: 48))
            .foregroundStyle(.white.opacity(0.5))

          Text("Couldn't load image")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
        }
      }
  }

  // MARK: - Top Left Icon

  @ViewBuilder
  private var topLeftIcon: some View {
    if shouldShowTopLeftIcon {
      VStack {
        HStack {
          Image("x-logo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 32, height: 32)
            .opacity(toss.platformType == .xPost ? 0.5 : 0.3)
          Spacer()
        }
        Spacer()
      }
      .padding(16)
    }
  }

  private var shouldShowTopLeftIcon: Bool {
    switch toss.platformType {
    case .xProfile, .xPost:
      return true
    default:
      return false
    }
  }

  // MARK: - Platform-specific Views

  private var platformBackgroundColor: Color {
    switch toss.platformType {
    case .github:
      return Color(red: 0.08, green: 0.08, blue: 0.08)
    case .youtube:
      return Color(red: 0.90, green: 0.0, blue: 0.0)
    case .xProfile, .xPost:
      return Color(red: 0.0, green: 0.0, blue: 0.0)
    case .genericWebsite, nil:
      return Color.gray
    }
  }

  private var platformBadge: some View {
    Group {
      switch toss.platformType {
      case .github:
        githubBadge
      case .youtube:
        youtubeBadge
      case .xProfile, .xPost:
        xBadge
      case .genericWebsite, nil:
        domainBadge
      }
    }
  }

  // MARK: - GitHub Views

  private var githubRepoName: String {
    guard let url = URL(string: toss.content) else {
      return ""
    }

    let pathComponents = url.pathComponents.filter { $0 != "/" }
    if pathComponents.count >= 2 {
      return "\(pathComponents[0])/\(pathComponents[1])"
    }
    return pathComponents.first ?? ""
  }

  private var githubBadge: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image("github-mark-white")
          .resizable()
          .frame(width: 12, height: 12)
        Text(githubRepoName)
          .font(.system(.caption, design: .monospaced))
          .fontWeight(.medium)
          .lineLimit(1)
      }
      .foregroundStyle(.white)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.black.opacity(0.8))
      .cornerRadius(8)
      .padding(12)
    }
  }

  // MARK: - YouTube Views

  private var youtubeBadge: some View {
    HStack(spacing: 6) {
      Image("yt-logo")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 16, height: 16)
      Text(toss.metadataTitle ?? "YouTube")
        .font(.caption)
        .fontWeight(.medium)
        .lineLimit(1)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(.black.opacity(0.8))
    .cornerRadius(8)
    .padding(12)
  }

  // MARK: - X/Twitter Views

  private var xBadge: some View {
    HStack(spacing: 6) {
      Image("x-logo")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 10, height: 10)
      Text(formattedXUsername)
        .font(.caption)
        .fontWeight(.medium)
        .lineLimit(1)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(.black.opacity(0.9))
    .cornerRadius(8)
    .padding(12)
  }

  private var formattedXUsername: String {
    guard let author = toss.metadataAuthor else { return "X" }
    // Add @ if not present
    return author.hasPrefix("@") ? author : "@\(author)"
  }

  // MARK: - Generic Domain Badge

  private var domainBadge: some View {
    HStack(spacing: 6) {
      Image(systemName: "safari")
        .font(.caption)
      Text(toss.metadataTitle ?? extractDomain(from: toss.content))
        .font(.caption)
        .lineLimit(1)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(.black.opacity(0.8))
    .cornerRadius(8)
    .padding(12)
  }

  // MARK: - Helper functions

  private var cardBackground: some ShapeStyle {
    #if os(macOS)
      return AnyShapeStyle(.thinMaterial)
    #else
      return AnyShapeStyle(.regularMaterial)
    #endif
  }

  private func platformImage(from data: Data) -> Image? {
    #if os(macOS)
      if let nsImage = NSImage(data: data) {
        return Image(nsImage: nsImage)
      }
    #else
      if let uiImage = UIImage(data: data) {
        return Image(uiImage: uiImage)
      }
    #endif
    return nil
  }

  private func extractDomain(from urlString: String) -> String {
    guard let url = URL(string: urlString),
      let host = url.host
    else {
      return urlString
    }
    return host.replacingOccurrences(
      of: "^www\\.",
      with: "",
      options: .regularExpression
    )
  }
}
