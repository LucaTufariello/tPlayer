import SwiftUI
import AppKit

enum LibrarySort: String, CaseIterable, Identifiable {
    case recent
    case title
    case duration

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recent: return "Recently added"
        case .title: return "Title"
        case .duration: return "Longest first"
        }
    }

    var icon: String {
        switch self {
        case .recent: return "clock"
        case .title: return "textformat"
        case .duration: return "hourglass"
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: LibraryStore

    var onOpenFilm: (Film) -> Void
    var onStartOver: (Film) -> Void
    var onPinPicker: () -> Void

    @State private var searchText = ""
    @State private var sort: LibrarySort = .recent
    @State private var filmToRemove: Film?
    @State private var filmToRename: Film?
    @State private var renameText = ""

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredFilms: [Film] {
        var list = store.films

        if isSearching {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.sourceFileName.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sort {
        case .recent:
            list.sort { $0.addedAt > $1.addedAt }
        case .title:
            list.sort { $0.sortTitle < $1.sortTitle }
        case .duration:
            list.sort { $0.duration > $1.duration }
        }

        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                searchText: $searchText,
                onImport: { store.chooseAndImport() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 42) {
                    if store.films.isEmpty {
                        EmptyLibraryView(onImport: { store.chooseAndImport() })
                    } else {
                        if !isSearching {
                            HeroSection(
                                pinned: store.pinnedFilm,
                                onOpen: onOpenFilm,
                                onStartOver: onStartOver,
                                onPinPicker: onPinPicker,
                                onUnpin: { store.unpin() },
                                onReveal: { film in store.revealInFinder(id: film.id) },
                                onRemove: { film in filmToRemove = film }
                            )

                            KeepWatchingSection(
                                films: store.continueFilms,
                                onOpen: onOpenFilm,
                                onStartOver: onStartOver,
                                onMarkWatched: { film in store.markWatched(id: film.id) },
                                onPin: { film in store.pin(film.id) },
                                onRemove: { film in filmToRemove = film }
                            )
                        }

                        LibrarySection(
                            films: filteredFilms,
                            totalCount: store.films.count,
                            isSearching: isSearching,
                            searchText: searchText,
                            sort: $sort,
                            pinnedID: store.pinnedFilmID,
                            onOpen: onOpenFilm,
                            onTogglePin: { film in store.togglePin(film.id) },
                            onMarkWatched: { film in store.markWatched(id: film.id) },
                            onMarkUnwatched: { film in store.markUnwatched(id: film.id) },
                            onReveal: { film in store.revealInFinder(id: film.id) },
                            onRename: { film in
                                renameText = film.title
                                filmToRename = film
                            },
                            onRemove: { film in filmToRemove = film },
                            onClearSearch: { searchText = "" }
                        )
                    }

                    Footer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 22)
                .padding(.bottom, 34)
                .frame(maxWidth: 1400, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .alert(
            "Remove film?",
            isPresented: Binding(
                get: { filmToRemove != nil },
                set: { if !$0 { filmToRemove = nil } }
            ),
            presenting: filmToRemove
        ) { film in
            Button("Remove", role: .destructive) {
                store.remove(id: film.id)
                filmToRemove = nil
            }
            Button("Cancel", role: .cancel) {
                filmToRemove = nil
            }
        } message: { film in
            Text("“\(film.title)” will be deleted from your library. The file you originally imported is not affected.")
        }
        .alert(
            "Rename film",
            isPresented: Binding(
                get: { filmToRename != nil },
                set: { if !$0 { filmToRename = nil } }
            ),
            presenting: filmToRename
        ) { film in
            TextField("Title", text: $renameText)
            Button("Save") {
                store.rename(id: film.id, title: renameText)
                filmToRename = nil
            }
            Button("Cancel", role: .cancel) {
                filmToRename = nil
            }
        } message: { _ in
            Text("Choose the title shown in your library.")
        }
    }
}

// MARK: - Top bar

private struct TopBar: View {
    @Binding var searchText: String
    var onImport: () -> Void

    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue

    var body: some View {
        HStack(spacing: 18) {
            BrandMark()

            Spacer(minLength: 20)

            SearchField(text: $searchText)

            AppearanceMenu(modeRaw: $appearanceModeRaw)

            Button(action: onImport) {
                Label("Import films", systemImage: "plus")
            }
            .buttonStyle(InkButtonStyle())
            .help("Import MP4, M4V, or MOV files  (⌘O)")
        }
        .padding(.leading, 92)
        .padding(.trailing, 36)
        .frame(height: 78)
        .background(Color.paper.opacity(0.86))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ink.opacity(0.075))
                .frame(height: 1)
        }
    }
}

private struct AppearanceMenu: View {
    @Binding var modeRaw: String

    private var mode: AppearanceMode {
        AppearanceMode(rawValue: modeRaw) ?? .system
    }

    var body: some View {
        Menu {
            Picker("Appearance", selection: $modeRaw) {
                ForEach(AppearanceMode.allCases) { option in
                    Label(option.label, systemImage: option.icon)
                        .tag(option.rawValue)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: mode.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.paperRaised))
                .overlay(Circle().strokeBorder(Color.ink.opacity(0.10), lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Appearance: \(mode.label)")
    }
}

struct BrandMark: View {    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.ink)
                    .frame(width: 29, height: 29)
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.paperRaised)
                    .offset(x: 1)
            }

            Text("tPlayer")
                .font(.display(24, weight: .medium))
                .foregroundStyle(Color.ink)

            Rectangle()
                .fill(Color.ink.opacity(0.14))
                .frame(width: 1, height: 15)
                .padding(.horizontal, 2)

            Eyebrow(text: "Private cinema", color: .inkTertiary)
        }
    }
}

private struct SearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(focused ? Color.terracotta : Color.inkTertiary)

            TextField("Search your films", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.ink)
                .tint(Color.terracotta)
                .focused($focused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 236, height: 34)
        .background(Capsule(style: .continuous).fill(Color.paperRaised))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    focused ? Color.terracotta.opacity(0.45) : Color.ink.opacity(0.10),
                    lineWidth: 1
                )
        )
        .animation(.easeOut(duration: 0.15), value: focused)
    }
}

// MARK: - Hero

private struct HeroSection: View {
    let pinned: Film?
    let onOpen: (Film) -> Void
    let onStartOver: (Film) -> Void
    let onPinPicker: () -> Void
    let onUnpin: () -> Void
    let onReveal: (Film) -> Void
    let onRemove: (Film) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.terracotta)
                Eyebrow(text: "Up next")
                Spacer()
                if pinned != nil {
                    Text("Pinned by you")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.inkTertiary)
                }
            }

            if let film = pinned {
                PinnedHero(
                    film: film,
                    onOpen: { onOpen(film) },
                    onStartOver: { onStartOver(film) },
                    onUnpin: onUnpin,
                    onReveal: { onReveal(film) },
                    onRemove: { onRemove(film) }
                )
            } else {
                PinPlaceholder(onPinPicker: onPinPicker)
            }
        }
    }
}

private struct PinnedHero: View {
    let film: Film
    let onOpen: () -> Void
    let onStartOver: () -> Void
    let onUnpin: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void

    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            FilmArtwork(film: film, alignment: .top)
                .scaleEffect(hovering ? 1.012 : 1)
                .animation(.easeOut(duration: 0.5), value: hovering)

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.02), location: 0.18),
                    .init(color: Color.black.opacity(0.38), location: 0.58),
                    .init(color: Color.black.opacity(0.82), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [Color.black.opacity(0.38), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(maxWidth: 620)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    BadgePill(
                        text: "Pinned next",
                        icon: "pin.fill",
                        foreground: Color.playerPaper,
                        background: Color.black.opacity(0.34)
                    )

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: onUnpin) {
                            Image(systemName: "pin.slash")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.playerPaper)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.black.opacity(0.34)))
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help("Unpin this film")

                        Menu {
                            Button("Reveal in Finder", action: onReveal)
                            Divider()
                            Button("Remove from library", role: .destructive, action: onRemove)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.playerPaper)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.black.opacity(0.34)))
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                    }
                }

                Spacer(minLength: 30)

                VStack(alignment: .leading, spacing: 12) {
                    Text(film.title)
                        .font(.display(42, weight: .regular))
                        .foregroundStyle(Color.playerPaper)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 4)

                    HStack(spacing: 10) {
                        Text(film.metaLine)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Color.playerPaper.opacity(0.72))

                        if film.hasProgress {
                            Circle()
                                .fill(Color.playerPaper.opacity(0.34))
                                .frame(width: 3, height: 3)
                            Text("Resume at \(TimeFormat.clock(film.progress))")
                                .font(.mono(11.5))
                                .foregroundStyle(Color.playerPaper.opacity(0.82))
                        }
                    }

                    if film.hasProgress {
                        VStack(alignment: .leading, spacing: 6) {
                            ThinProgressBar(
                                progress: film.progressFraction,
                                track: Color.white.opacity(0.22),
                                fill: Color.terracotta,
                                height: 3
                            )
                            .frame(width: 248)

                            Text(TimeFormat.remaining(film.remaining))
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.playerPaper.opacity(0.56))
                        }
                        .padding(.top, 2)
                    }

                    HStack(spacing: 12) {
                        Button(action: onOpen) {
                            Label(
                                film.hasProgress ? "Resume" : "Play film",
                                systemImage: "play.fill"
                            )
                        }
                        .buttonStyle(AccentButtonStyle())

                        if film.hasProgress {
                            Button(action: onStartOver) {
                                Label("Start over", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.playerPaper.opacity(0.78))
                            .padding(.horizontal, 4)
                            .help("Open the film from the beginning")
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(30)
        }
        .frame(height: 372)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.shadow.opacity(0.20), radius: 28, x: 0, y: 16)
        .onHover { hovering = $0 }
        .contextMenu {
            Button(film.hasProgress ? "Resume" : "Play", action: onOpen)
            if film.hasProgress {
                Button("Start over", action: onStartOver)
            }
            Button("Unpin", action: onUnpin)
            Button("Reveal in Finder", action: onReveal)
            Divider()
            Button("Remove from library", role: .destructive, action: onRemove)
        }
    }
}

private struct PinPlaceholder: View {
    let onPinPicker: () -> Void

    var body: some View {
        HStack(spacing: 30) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose what’s next.")
                    .font(.display(33, weight: .regular))
                    .foregroundStyle(Color.ink)

                Text("Pin a film from your library and it will wait for you right here — a quiet promise for later.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color.inkSecondary)
                    .lineSpacing(3)
                    .frame(maxWidth: 430, alignment: .leading)

                Button(action: onPinPicker) {
                    Label("Pin a film", systemImage: "pin")
                }
                .buttonStyle(InkButtonStyle())
                .padding(.top, 4)
            }

            Spacer(minLength: 10)

            PosterStack()
                .frame(width: 250, height: 150)
        }
        .padding(.horizontal, 32)
        .frame(height: 224)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.paperRaised.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    Color.ink.opacity(0.16),
                    style: StrokeStyle(lineWidth: 1, dash: [7, 7])
                )
        )
    }
}

private struct PosterStack: View {
    var body: some View {
        ZStack {
            poster(rotation: -9, offset: CGSize(width: -58, height: 7), opacity: 0.55)
            poster(rotation: 8, offset: CGSize(width: 62, height: 3), opacity: 0.72)
            poster(rotation: 0, offset: .zero, opacity: 1)
        }
    }

    private func poster(rotation: Double, offset: CGSize, opacity: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.paperRaised)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.ink.opacity(0.12), lineWidth: 1)
            VStack(spacing: 8) {
                Circle()
                    .fill(Color.ink)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.paperRaised)
                            .offset(x: 1)
                    )
                Rectangle()
                    .fill(Color.ink.opacity(0.14))
                    .frame(width: 54, height: 4)
                    .clipShape(Capsule())
                Rectangle()
                    .fill(Color.ink.opacity(0.09))
                    .frame(width: 34, height: 3)
                    .clipShape(Capsule())
            }
        }
        .frame(width: 132, height: 82)
        .rotationEffect(.degrees(rotation))
        .offset(offset)
        .opacity(opacity)
        .shadow(color: Color.shadow.opacity(0.12), radius: 12, x: 0, y: 7)
    }
}

// MARK: - Keep watching

private struct KeepWatchingSection: View {
    let films: [Film]
    let onOpen: (Film) -> Void
    let onStartOver: (Film) -> Void
    let onMarkWatched: (Film) -> Void
    let onPin: (Film) -> Void
    let onRemove: (Film) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Keep watching") {
                Text(films.isEmpty ? "Nothing in progress" : "\(films.count) in progress")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.inkTertiary)
            }

            if films.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.inkTertiary)
                    Text("Start a film and we’ll keep your place, right to the second.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.inkSecondary)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .frame(height: 76)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.paperRaised.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            Color.ink.opacity(0.10),
                            style: StrokeStyle(lineWidth: 1, dash: [6, 6])
                        )
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(films) { film in
                            ContinueCard(
                                film: film,
                                onOpen: { onOpen(film) },
                                onStartOver: { onStartOver(film) },
                                onMarkWatched: { onMarkWatched(film) },
                                onPin: { onPin(film) },
                                onRemove: { onRemove(film) }
                            )
                        }
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 1)
                }
                .scrollClipDisabled()
            }
        }
    }
}

private struct ContinueCard: View {
    let film: Film
    let onOpen: () -> Void
    let onStartOver: () -> Void
    let onMarkWatched: () -> Void
    let onPin: () -> Void
    let onRemove: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottom) {
                    FilmArtwork(film: film)
                        .frame(height: 174)
                        .clipped()

                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.58)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            BadgePill(
                                text: "\(Int((film.progressFraction * 100).rounded()))% watched",
                                foreground: Color.playerPaper,
                                background: Color.black.opacity(0.34)
                            )
                            Spacer()
                            if hovering {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.ink)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.paperRaised))
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }

                        ThinProgressBar(
                            progress: film.progressFraction,
                            track: Color.white.opacity(0.24),
                            fill: Color.terracotta,
                            height: 4
                        )
                    }
                    .padding(13)
                }
                .frame(height: 174)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(film.title)
                        .font(.display(17.5, weight: .medium))
                        .foregroundStyle(Color.ink)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(TimeFormat.remaining(film.remaining))
                        Text("·")
                        Text("Resume \(TimeFormat.clock(film.progress))")
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.inkSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 308)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.paperRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.ink.opacity(0.085), lineWidth: 1)
            )
            .shadow(
                color: Color.shadow.opacity(hovering ? 0.14 : 0.07),
                radius: hovering ? 22 : 14,
                x: 0,
                y: hovering ? 12 : 8
            )
            .scaleEffect(hovering ? 1.012 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.2), value: hovering)
        .contextMenu {
            Button("Resume", action: onOpen)
            Button("Start over", action: onStartOver)
            Button("Mark as watched", action: onMarkWatched)
            Button("Pin as next watch", action: onPin)
            Divider()
            Button("Remove from library", role: .destructive, action: onRemove)
        }
        .help("Resume “\(film.title)”")
    }
}

// MARK: - Library

private struct LibrarySection: View {
    let films: [Film]
    let totalCount: Int
    let isSearching: Bool
    let searchText: String
    @Binding var sort: LibrarySort
    let pinnedID: UUID?
    let onOpen: (Film) -> Void
    let onTogglePin: (Film) -> Void
    let onMarkWatched: (Film) -> Void
    let onMarkUnwatched: (Film) -> Void
    let onReveal: (Film) -> Void
    let onRename: (Film) -> Void
    let onRemove: (Film) -> Void
    let onClearSearch: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 340), spacing: 22, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Eyebrow(text: isSearching ? "Search results" : "Your library")

                Text("\(isSearching ? films.count : totalCount)")
                    .font(.mono(10.5))
                    .foregroundStyle(Color.inkTertiary)

                Rectangle()
                    .fill(Color.ink.opacity(0.09))
                    .frame(height: 1)

                SortMenu(sort: $sort)
            }

            if films.isEmpty {
                NoResultsView(searchText: searchText, onClear: onClearSearch)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
                    ForEach(films) { film in
                        FilmCard(
                            film: film,
                            isPinned: film.id == pinnedID,
                            onOpen: { onOpen(film) },
                            onTogglePin: { onTogglePin(film) },
                            onMarkWatched: { onMarkWatched(film) },
                            onMarkUnwatched: { onMarkUnwatched(film) },
                            onReveal: { onReveal(film) },
                            onRename: { onRename(film) },
                            onRemove: { onRemove(film) }
                        )
                    }
                }
            }
        }
    }
}

private struct SortMenu: View {
    @Binding var sort: LibrarySort

    var body: some View {
        Menu {
            ForEach(LibrarySort.allCases) { option in
                Button {
                    sort = option
                } label: {
                    if option == sort {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 9.5, weight: .semibold))
                Text(sort.label)
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(Color.inkSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.paperRaised))
            .overlay(Capsule().strokeBorder(Color.ink.opacity(0.10), lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sort your library")
    }
}

private struct FilmCard: View {
    let film: Film
    let isPinned: Bool
    let onOpen: () -> Void
    let onTogglePin: () -> Void
    let onMarkWatched: () -> Void
    let onMarkUnwatched: () -> Void
    let onReveal: () -> Void
    let onRename: () -> Void
    let onRemove: () -> Void

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay {
                        FilmArtwork(film: film)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .bottom) {
                        if film.hasProgress {
                            ThinProgressBar(
                                progress: film.progressFraction,
                                track: Color.white.opacity(0.24),
                                fill: Color.terracotta,
                                height: 3
                            )
                            .padding(.horizontal, 11)
                            .padding(.bottom, 10)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if film.isWatched {
                            BadgePill(
                                text: "Watched",
                                icon: "checkmark",
                                foreground: Color.playerPaper,
                                background: Color.black.opacity(0.42)
                            )
                            .padding(10)
                        } else if isPinned {
                            BadgePill(
                                text: "Up next",
                                icon: "pin.fill",
                                foreground: Color.paperRaised,
                                background: Color.ink.opacity(0.82)
                            )
                            .padding(10)
                        }
                    }

                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(isPinned ? Color.onAccent : Color.ink)
                        .frame(width: 29, height: 29)
                        .background(
                            Circle().fill(
                                isPinned ? Color.terracotta : Color.paperRaised.opacity(0.92)
                            )
                        )
                        .overlay(Circle().strokeBorder(Color.ink.opacity(isPinned ? 0 : 0.10), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(9)
                .opacity(hovering || isPinned ? 1 : 0)
                .scaleEffect(hovering || isPinned ? 1 : 0.9)
                .animation(.easeOut(duration: 0.16), value: hovering)
                .help(isPinned ? "Unpin from Up next" : "Pin as next watch")
            }
            .onTapGesture(perform: onOpen)
            .contextMenu {
                Button(film.hasProgress ? "Resume" : "Play", action: onOpen)
                Button(isPinned ? "Unpin from Up next" : "Pin as next watch", action: onTogglePin)
                Divider()
                if film.isWatched {
                    Button("Mark as unwatched", action: onMarkUnwatched)
                } else {
                    Button("Mark as watched", action: onMarkWatched)
                }
                Button("Rename…", action: onRename)
                Button("Reveal in Finder", action: onReveal)
                Divider()
                Button("Remove from library", role: .destructive, action: onRemove)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(film.title)
                    .font(.display(17, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    Text(film.metaLine)
                    if film.hasProgress {
                        Text("·")
                        Text("\(TimeFormat.clock(film.progress)) in")
                            .foregroundStyle(Color.terracotta)
                    } else if film.isWatched {
                        Text("·")
                        Text("Watched")
                            .foregroundStyle(Color.sage)
                    }
                }
                .font(.system(size: 10.5))
                .foregroundStyle(Color.inkSecondary)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .scaleEffect(hovering ? 1.012 : 1)
        .shadow(
            color: Color.shadow.opacity(hovering ? 0.13 : 0),
            radius: 18,
            x: 0,
            y: 9
        )
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.18), value: hovering)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            "\(film.title), \(film.metaLine)"
                + (film.hasProgress ? ", \(TimeFormat.clock(film.progress)) in" : "")
                + (film.isWatched ? ", watched" : "")
                + (isPinned ? ", up next" : "")
        )
        .accessibilityAction(named: Text(isPinned ? "Unpin from Up next" : "Pin as next watch")) {
            onTogglePin()
        }
        .help(film.title)
    }
}

private struct NoResultsView: View {
    let searchText: String
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.inkTertiary)
            Text("No films match “\(searchText)”.")
                .font(.display(20))
                .foregroundStyle(Color.ink)
            Button("Clear search", action: onClear)
                .buttonStyle(InkButtonStyle(compact: true))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.paperRaised.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    Color.ink.opacity(0.10),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 6])
                )
        )
    }
}

// MARK: - Empty state

private struct EmptyLibraryView: View {
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 26) {
            EmptyPosterStack()

            VStack(spacing: 13) {
                Eyebrow(text: "Your private cinema", color: .terracotta)

                Text("Your cinema,\non paper.")
                    .font(.display(54, weight: .regular))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
                    .lineSpacing(-2)

                Text("Bring your films in. They stay on this Mac — no accounts, no cloud, no noise.")
                    .font(.system(size: 14.5))
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 430)
            }

            VStack(spacing: 10) {
                Button(action: onImport) {
                    Label("Import your first film", systemImage: "plus")
                }
                .buttonStyle(AccentButtonStyle())

                Text("or drop MP4, M4V, or MOV files anywhere")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.inkTertiary)
            }

            HStack(spacing: 0) {
                FeatureNote(icon: "lock", text: "Stays on this Mac")
                FeatureDivider()
                FeatureNote(icon: "clock.arrow.circlepath", text: "Remembers your place")
                FeatureDivider()
                FeatureNote(icon: "pin", text: "Pin what’s next")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .padding(.horizontal, 30)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.paperRaised.opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(
                    Color.ink.opacity(0.10),
                    style: StrokeStyle(lineWidth: 1, dash: [8, 9])
                )
        )
    }
}

private struct EmptyPosterStack: View {
    var body: some View {
        ZStack {
            frame(rotation: -10, offset: CGSize(width: -72, height: 9), opacity: 0.55)
            frame(rotation: 9, offset: CGSize(width: 74, height: 5), opacity: 0.72)
            frame(rotation: 0, offset: .zero, opacity: 1)
        }
        .frame(height: 126)
    }

    private func frame(rotation: Double, offset: CGSize, opacity: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.paperRaised)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.ink.opacity(0.13), lineWidth: 1)

            VStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(Color.terracotta)
                        .frame(width: 42, height: 42)
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.onAccent)
                        .offset(x: 1.5)
                }
                Rectangle()
                    .fill(Color.ink.opacity(0.12))
                    .frame(width: 62, height: 4)
                    .clipShape(Capsule())
                Rectangle()
                    .fill(Color.ink.opacity(0.07))
                    .frame(width: 38, height: 3)
                    .clipShape(Capsule())
            }
        }
        .frame(width: 158, height: 98)
        .rotationEffect(.degrees(rotation))
        .offset(offset)
        .opacity(opacity)
        .shadow(color: Color.shadow.opacity(0.14), radius: 16, x: 0, y: 9)
    }
}

private struct FeatureNote: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.inkSecondary)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.inkSecondary)
        }
        .padding(.horizontal, 18)
    }
}

private struct FeatureDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.ink.opacity(0.10))
            .frame(width: 1, height: 16)
    }
}

private struct Footer: View {
    var body: some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(Color.ink.opacity(0.075))
                .frame(height: 1)

            HStack {
                Text("tPlayer")
                    .font(.display(13, weight: .medium))
                    .foregroundStyle(Color.inkTertiary)
                Spacer()
                Text("Your films never leave this Mac.")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.inkTertiary)
            }
        }
        .padding(.top, 10)
    }
}
