# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Nexus — a personal "AI life operating system" for iOS 26. A single dark-themed app that bundles Notes, Tasks, Calendar, Health (incl. Nutrition), Finance (Transactions, Budgets, Subscriptions, Stocks, House/Utilities), and an AI Assistant. Solo personal app, bundle id `com.khizanag.nexus-app`, GitHub `Khizanag/Nexus-iOS`, git author email `khizanag@gmail.com`.

## Build / run / test

The Xcode project is the source of truth, not raw SwiftPM. `Nexus/Package.swift` defines a local `Nexus` library target whose sources live in `Nexus/Sources`; the Xcode project consumes it. Two targets/schemes: `Nexus` (app) and `NexusWidgets` (widget + Control Center extension).

```bash
# Build app for simulator (pick an installed iOS 26 simulator; name may differ)
xcodebuild -project Nexus.xcodeproj -scheme Nexus \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# List what's available if the destination fails
xcodebuild -list -project Nexus.xcodeproj
xcrun simctl list devices available
```

Prefer the **XcodeBuildMCP** tools (`build_sim`, `build_run_sim`, `list_sims`, `screenshot`, `snapshot_ui`) over raw `xcodebuild` — call `session_show_defaults` first to confirm project/scheme/simulator.

**Tests:** there are none yet. `Package.swift` declares a `NexusTests` target pointing at a `Tests/` directory that does not exist, so `swift test` fails until that directory is created. The Xcode project has no test target. Add tests with Swift Testing (`@Test`/`#expect`), not XCTest.

**Lint:** no `.swiftlint.yml` is committed despite the house rules expecting one. If you add SwiftLint, expect a large backlog — the codebase currently violates several personal rules (see below).

## Requirements

iOS **26.0** minimum, Swift **6** (strict concurrency), `objectVersion = 77` project (uses `PBXFileSystemSynchronizedRootGroup` — folders are synchronized, so new files added on disk under `Nexus/Sources` are picked up automatically; do not hand-edit `project.pbxproj` to register files). Capabilities: HealthKit, Sign in with Apple, CloudKit, app group `group.com.khizanag.nexus`, ubiquity KVS.

## Architecture — the big picture

### Persistence is the backbone (SwiftData + CloudKit)
All app state is SwiftData `@Model` classes under `Core/Data/SwiftData/`. The single `ModelContainer` is built in `NexusApp.init` with a 22-model `Schema` and a three-tier fallback: CloudKit (`.automatic`) → local store at `documentsDirectory/Nexus.sqlite` → default container. Views read/write data directly via `@Query` and `@Environment(\.modelContext)` — there is **no repository layer between views and the store** (see next point). When you add a model, you must register it in the `Schema` array in `NexusApp.init`, and CloudKit constraints apply (no `@Attribute(.unique)`, relationships must be optional, no `@Index` that CloudKit rejects).

### Clean-Architecture folders exist but are empty — do not be misled
`Core/Domain/{Repositories,UseCases}` and `Core/Data/{Repositories,DataSources}` are empty directories, and `DependencyContainer.registerRepositories()` / `registerUseCases()` are empty stubs. The app does **not** use a repository/use-case pattern in practice. Real data flow is: SwiftUI View → `@Query`/`modelContext` → SwiftData model. Don't assume an abstraction exists because the folder does; check before building on it.

### Dependency injection is half-wired
`DependencyContainer.shared` wraps a Swinject `Container` and an `@Inject` property wrapper exists, but only a handful of services are registered (AI, Keychain, Auth, Sync, Currency) and most code does **not** resolve through it. The dominant pattern is **singletons** (`DefaultCalendarService.shared`, `AssistantLauncher.shared`, `TaskLauncher.shared`, `CartService`-style `@MainActor @Observable final class … static let shared`) plus per-view `@State` services. Treat Swinject as legacy/partial; match the singleton-or-`@State` pattern that the surrounding screen already uses.

### Services layer (`Sources/Services/<Domain>/`)
`@MainActor @Observable` classes wrapping system frameworks and APIs: AI (Anthropic), Auth + Keychain, Calendar (EventKit), Contacts, Currency (FX rates + cache), Health (HealthKit), Location, Notifications (separate Task and Subscription notification services), Speech (`SFSpeechRecognizer`), Stocks (quotes), Sync (CloudKit/account). Each typically exposes a `protocol` + `Default…` implementation.

### Presentation (`Core/Presentation/Screens/<Feature>/`)
One folder per feature; large feature folders split into `…View`, `…ComponentS`, `…EditorView`, `…DetailView`, plus `…SummaryCard`. There is **no coordinator/Screen-enum navigation** here (unlike the house `navigation-pattern.md`). Navigation is:
- `RootView` owns a `TabView` bound to the `Tab` enum (`home`, `tasks`, `assistant`, `health`, `finance`).
- The `assistant` tab is a **decoy** — selecting it doesn't switch tabs; `ChangeHandlersModifier` intercepts the selection and presents `AssistantView` as a sheet, then restores the previous tab.
- Sheets are driven by `@State` booleans/items in `RootView` via `SheetModifier` (Assistant, QuickWaterLog, Calendar, Settings, TaskEditor).
- Deep cross-app navigation (from widgets, notifications, and the assistant) flows through singletons: `WidgetDataStore.consumePendingAction()`, `TaskLauncher`, and `AssistantLauncher` (`AssistantNavigation` enum), consumed in `RootView`'s `onChange(of: scenePhase)`/sheet-dismiss handlers. Child screens use `NavigationStack` locally.

### The "AI Assistant" is currently a rule-based parser, not an LLM chat
This is the single most important thing to understand before touching the assistant. `AssistantView.generateResponse(for:)` is a ~1000-line hand-rolled intent engine: it lowercases the input and runs ordered keyword/`NSRegularExpression` matches (`parseTaskAction`, `parseHealthAction`, `parseOpenAction`, `generate…Response`) to either mutate SwiftData (create task/note/subscription, log health, complete task) or emit canned markdown strings summarizing `@Query` data. `DefaultAIService` (real Anthropic call gated on `ANTHROPIC_API_KEY`, mock fallback) **exists but is not wired into the chat** — `sendMessage` is never called from `AssistantView`. `ChatMessage` (in-memory, with a rich `MessageType` enum) is the view model; `ChatMessageModel` is the SwiftData persistence mirror, converted by hand in `loadSavedMessages`/`saveMessage`.

### Design system (`Sources/Design/`)
`Theme/` defines flat `Color` and `Font` extensions (`.nexusPurple`, `.nexusBackground`, `.nexusHeadline`, …) plus a `Color(hex:)` initializer — **not** the house `DesignSystem.*` enum namespace. `Component/` holds reusable views (`NexusCard`, `NexusButton`, `ConcentricRectangle`, `EmptyStateView`, `FilterChip`, `NutritionProgressRing`, …). Glass/translucency is hand-rolled with `.ultraThinMaterial` + gradient stroke overlays (`GlassCard`, the assistant bubbles) rather than the iOS 26 `glassEffect`/`GlassEffectContainer` APIs. The app is **dark-mode-only**: `RootView` forces `.preferredColorScheme(.dark)` and the palette is hardcoded dark hex with no light variant or asset-catalog colors.

### Widgets & extensions
`NexusWidgets/` is a separate target: Control Center controls (`LogWaterControl`, `OpenAssistantControl`) and `NexusWidgetsBundle`. It shares `WidgetActions`/`WidgetDataStore` with the app via the app group; the app drains pending widget actions on scene activation. `Sources/App/Intents/OpenAssistantIntent.swift` exposes an App Intent.

## Conventions specific to this repo

- New files: just create them on disk under the right `Sources/<area>/<Feature>/` folder — the synchronized project picks them up. Folder names are singular PascalCase (`View`, `Service`, `Component`).
- Feature screens keep their view extensions in `private extension <View>` blocks grouped by `// MARK:` (toolbar, body sections, actions) — match this when extending a screen.
- Cross-feature side effects (notifications, navigation, widget state) go through the existing `*.shared` singletons, not new DI registrations.
- This is a personal app: the broader `~/.claude` house rules apply (SwiftUI-only, offline-first, accessibility, localization-ready, no AI attribution in commits), but note the repo currently diverges from several of them (forced dark mode, inline `.font(.system(size:))`, hardcoded dimensions, no `DesignSystem` namespace, no SwiftLint). When asked to "follow house style," reconcile against these existing divergences rather than assuming compliance.
