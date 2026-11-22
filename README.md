# HobbyAtlas

A free, open-source project manager built for hobbies: gardening, model building, electronics, woodworking, collections and personal projects. Native macOS (SwiftUI), local-first, every feature included. No account, no subscription, no paywall.

## Build & run

```bash
./build.sh                 # builds build/HobbyAtlas.app (Apple Silicon, macOS 14+)
open build/HobbyAtlas.app
```

Uses Xcode's toolchain when it's installed, because newer SDKs need it for SwiftUI's `@State` macro. There are no third-party dependencies.

Render screenshots with demo data (a throwaway library, so your real data is never touched):

```bash
HOBBYATLAS_SNAPSHOT=$PWD/build/snapshots ./build/HobbyAtlas.app/Contents/MacOS/HobbyAtlas
```

## Features

- **Library dashboard**: project cards with cover photo, status, progress and counts. Stats for active, finished, photos and money still to spend. Filter by hobby or *In Progress*, search, and sort. Unlimited projects.
- **Hobby templates**: each hobby has a starter template with board columns, starter cards and a materials list. You can also start from a blank board.
- **Custom project boards**: a kanban with columns you rename, add, reorder and delete. Drag cards between columns. Cards have labels, due dates, notes and checklists. Progress is the share of cards in the last column.
- **Materials lists**: quantity, unit, unit cost, status (Need / Ordered / Have) and supplier or link. Shows budget, still to buy, ordered and in-hand totals. One click copies a shopping list. Currency can be changed in Settings.
- **Photo progress**: drag and drop or import photos. The timeline is grouped by month using each photo's EXIF capture date. Add captions, pick a cover photo, and compare two photos with a before/after slider.
- **Notes** tab for each project.

## Data

Everything lives in `~/Library/Application Support/HobbyAtlas`: a human-readable `library.json` plus a `Photos/` folder. Settings › General has a button that opens this folder.

## Project layout

| File | What's in it |
|---|---|
| `Sources/Models.swift` | Codable data model (projects, columns, cards, materials, photos) |
| `Sources/Store.swift` | JSON persistence, photo import, thumbnail cache |
| `Sources/Templates.swift` | Built-in hobby templates. A good first place to contribute |
| `Sources/ContentView.swift` | Sidebar, project grid, new-project sheet |
| `Sources/ProjectDetailView.swift`, `BoardView.swift`, `MaterialsView.swift`, `PhotosView.swift` | Project screens |
| `Sources/Snapshot.swift` | Demo-data screenshot mode |

## Contributing

Issues and pull requests are welcome. New hobby templates, translations and the ideas in [ROADMAP.md](ROADMAP.md) are good places to start.

## License

[MIT](LICENSE)
