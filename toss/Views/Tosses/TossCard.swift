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

    var body: some View {
        if toss.type == .link {
            // Link card - cinematic aspect ratio
            ZStack(alignment: .bottomLeading) {
                Color.clear
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .overlay {
                        if hasAttemptedLoad && toss.imageData == nil {
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
                                .fill(
                                    isGitHub
                                        ? Color(
                                            red: 0.08,
                                            green: 0.08,
                                            blue: 0.08
                                        ) : Color.gray
                                )
                                .overlay {
                                    if isGitHub {
                                        githubPlaceholder
                                    }
                                }
                        }
                    }
                    .clipped()
                    .cornerRadius(12)

                // GitHub-specific or regular badge
                if isGitHub {
                    githubBadge
                } else {
                    domainBadge
                }
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
                .overlay {
                    VStack(alignment: .leading, spacing: 8) {
                        Markdown(toss.content)
                            .lineLimit(4)

                        Spacer()

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

    // MARK: - GitHub specific views

    private var isGitHub: Bool {
        guard let url = URL(string: toss.content),
            let host = url.host
        else {
            return false
        }
        return host.contains("github.com")
    }

    private var githubRepoName: String {
        guard let url = URL(string: toss.content) else {
            return ""
        }

        // Parse GitHub URL for repo name
        // e.g., https://github.com/pseudobun/toss -> pseudobun/toss
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
            // Repo name in bottom left
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

    private var domainBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "safari")
                .font(.caption)
            Text(extractDomain(from: toss.content))
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
            let url = URL(string: toss.content)
        else {
            return
        }

        hasAttemptedLoad = true

        WebsiteMetadataFetcher.fetchOGImage(url: url) { image in
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
