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
    @State private var hasAttemptedLoad = false
    @State private var isLoadingImage = false
    @State private var metadata: WebsiteMetadata?

    var body: some View {
        if toss.type == .link {
            // Link card - cinematic aspect ratio
            ZStack(alignment: .bottomLeading) {
                Color.clear
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .overlay {
                        if isLoadingImage {
                            // Loading spinner
                            ProgressView()
                                .scaleEffect(1)
                        } else if let imageData = toss.imageData,
                            let image = platformImage(from: imageData)
                        {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            // Platform-specific placeholder
                            Rectangle()
                                .fill(platformBackgroundColor)
                                .overlay {
                                    platformPlaceholder
                                }
                        }
                    }
                    .clipped()
                    .cornerRadius(12)

                // Metadata overlay (for Twitter/X and other platforms with text)
                if shouldShowMetadataOverlay {
                    metadataOverlay
                }

                // Platform-specific badge
                platformBadge
            }
            .contentShape(Rectangle())
            .onAppear {
                fetchImageIfNeeded()
            }
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
            // Text card - same aspect ratio
            Color.clear
                .aspectRatio(4 / 3, contentMode: .fit)
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
                    .padding(12)
                }
                .background(cardBackground)
                .cornerRadius(12)
                .clipped()
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

    // MARK: - Platform Detection

    private enum PlatformType {
        case github
        case youtube
        case twitter
        case other
    }

    private var platformType: PlatformType {
        guard let url = URL(string: toss.content),
            let host = url.host
        else {
            return .other
        }

        if host.contains("github.com") {
            return .github
        } else if host.contains("youtube.com") || host.contains("youtu.be") {
            return .youtube
        } else if host.contains("twitter.com") || host.contains("x.com") {
            return .twitter
        }

        return .other
    }

    // MARK: - Metadata Overlay

    private var shouldShowMetadataOverlay: Bool {
        // Show metadata overlay for Twitter/X posts with description
        return platformType == .twitter && metadata?.description != nil
    }

    private var metadataOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            // Gradient background for better text readability
            VStack(alignment: .leading, spacing: 6) {
                // Tweet text / description
                if let description = metadata?.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                // Author name (if available)
                if let author = metadata?.author {
                    HStack(spacing: 4) {
                        Text("𝕏")
                            .font(.system(size: 10, weight: .bold))
                        Text(author)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .black.opacity(0.3),
                        .black.opacity(0.7),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Platform-specific Views

    private var platformBackgroundColor: Color {
        switch platformType {
        case .github:
            return Color(red: 0.08, green: 0.08, blue: 0.08)
        case .youtube:
            return Color(red: 0.90, green: 0.0, blue: 0.0)  // YouTube red
        case .twitter:
            return Color(red: 0.0, green: 0.0, blue: 0.0)  // Twitter/X black
        case .other:
            return Color.gray
        }
    }

    private var platformPlaceholder: some View {
        Group {
            switch platformType {
            case .github:
                githubPlaceholder
            case .youtube:
                youtubePlaceholder
            case .twitter:
                twitterPlaceholder
            case .other:
                EmptyView()
            }
        }
    }

    private var platformBadge: some View {
        Group {
            switch platformType {
            case .github:
                githubBadge
            case .youtube:
                youtubeBadge
            case .twitter:
                twitterBadge
            case .other:
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

    private var githubPlaceholder: some View {
        VStack {
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.1))

            Text("GitHub")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.3))
        }
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

    private var youtubeVideoId: String? {
        guard let url = URL(string: toss.content) else { return nil }

        // Handle youtu.be short links
        if url.host?.contains("youtu.be") == true {
            return url.pathComponents.last
        }

        // Handle youtube.com/watch?v= links
        if let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ),
            let videoId = components.queryItems?.first(where: { $0.name == "v" }
            )?.value
        {
            return videoId
        }

        // Handle youtube.com/embed/ links
        if url.pathComponents.contains("embed"),
            let videoId = url.pathComponents.last
        {
            return videoId
        }

        return nil
    }

    private var youtubePlaceholder: some View {
        VStack {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 4)

            Text("YouTube")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }

    private var youtubeBadge: some View {
        HStack(spacing: 6) {
            Image("yt-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)  // Changed from 12x12 to 16x16
            Text(metadata?.title ?? "YouTube")
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

    // MARK: - Twitter/X Views

    private var twitterHandle: String {
        // Try to get from metadata first
        if let author = metadata?.author {
            return author.hasPrefix("@") ? author : "@\(author)"
        }

        // Fallback to URL parsing
        guard let url = URL(string: toss.content) else { return "" }
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        if let handle = pathComponents.first {
            return "@\(handle)"
        }
        return ""
    }

    private var twitterPlaceholder: some View {
        VStack {
            // X logo (simplified)
            Text("𝕏")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))

            Text("Post")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var twitterBadge: some View {
        HStack(spacing: 6) {
            Image("x-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 10, height: 10)
            Text(twitterHandle.isEmpty ? "X" : twitterHandle)
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

    // MARK: - Generic Domain Badge

    private var domainBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "safari")
                .font(.caption)
            Text(metadata?.title ?? extractDomain(from: toss.content))
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

    private func fetchImageIfNeeded() {
        guard toss.type == .link,
            toss.imageData == nil,
            !hasAttemptedLoad,
            let url = URL(string: toss.content)
        else {
            return
        }

        hasAttemptedLoad = true
        isLoadingImage = true

        // Special handling for YouTube - fetch thumbnail directly
        if platformType == .youtube, let videoId = youtubeVideoId {
            // Fetch metadata for title
            WebsiteMetadataFetcher.fetchMetadata(url: url) { fetchedMetadata in
                self.metadata = fetchedMetadata
            }
            fetchYouTubeThumbnail(videoId: videoId)
            return
        }

        // Use the enhanced metadata fetcher for other platforms
        WebsiteMetadataFetcher.fetchMetadata(url: url) { fetchedMetadata in
            self.metadata = fetchedMetadata

            if let image = fetchedMetadata.image {
                // Got image from OG tags
                isLoadingImage = false

                #if os(macOS)
                    if let imageData = image.tiffRepresentation {
                        toss.imageData = imageData
                        try? modelContext.save()
                    }
                #else
                    if let imageData = image.pngData() {
                        toss.imageData = imageData
                        try? modelContext.save()
                    }
                #endif
            } else {
                // No OG image, fallback to screenshot
                WebsiteMetadataFetcher.fetchImageOrScreenshot(url: url) {
                    image in
                    isLoadingImage = false

                    #if os(macOS)
                        if let imageData = image?.tiffRepresentation {
                            toss.imageData = imageData
                            try? modelContext.save()
                        }
                    #else
                        if let imageData = image?.pngData() {
                            toss.imageData = imageData
                            try? modelContext.save()
                        }
                    #endif
                }
            }
        }
    }

    private func fetchYouTubeThumbnail(videoId: String) {
        // YouTube thumbnail URLs - try maxresdefault first, fallback to hqdefault
        let thumbnailURLs = [
            "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg",
            "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg",
        ]

        fetchThumbnailFromURLs(thumbnailURLs, index: 0)
    }

    private func fetchThumbnailFromURLs(_ urls: [String], index: Int) {
        guard index < urls.count,
            let url = URL(string: urls[index])
        else {
            isLoadingImage = false
            return
        }

        URLSession.shared.dataTask(with: url) { [self] data, response, error in
            // Check if we got a valid image (maxresdefault might not exist for all videos)
            if let data = data,
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200,
                data.count > 1000
            {  // Ensure it's not a placeholder image

                DispatchQueue.main.async {
                    self.isLoadingImage = false
                    self.toss.imageData = data
                    try? self.modelContext.save()
                }
            } else {
                // Try next thumbnail URL
                self.fetchThumbnailFromURLs(urls, index: index + 1)
            }
        }.resume()
    }

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
