# Ponude — Architecture & Developer Guide

> **Ponude** is a native macOS SwiftUI application for creating, managing, and exporting professional business quotes (ponude) as pixel-perfect A4 PDFs. It supports multiple business profiles, a local client database with Croatian Court Register (Sudreg) API integration, and a real-time WYSIWYG quote preview.

---

## Table of Contents

1. [Tech Stack & Requirements](#tech-stack--requirements)
2. [Project Structure](#project-structure)
3. [Architecture Overview](#architecture-overview)
4. [Data Model (SwiftData)](#data-model-swiftdata)
5. [Views & Navigation](#views--navigation)
6. [Services](#services)
7. [Helpers & Design System](#helpers--design-system)
8. [Build & Run](#build--run)
9. [Key Workflows](#key-workflows)
10. [Configuration & Settings](#configuration--settings)
11. [File-by-File Reference](#file-by-file-reference)

---

## Tech Stack & Requirements

| Layer           | Technology                               |
|-----------------|------------------------------------------|
| **Language**    | Swift 5.10                               |
| **UI**          | SwiftUI (macOS 14+)                      |
| **Persistence** | SwiftData (`@Model`, `ModelContainer`)   |
| **PDF Engine**  | WebKit (`WKWebView.createPDF`)           |
| **Networking**  | `URLSession` (OAuth2 → Sudreg REST API)  |
| **Build**       | Swift Package Manager (SPM)              |
| **Bundle ID**   | `hr.lotusrc.ponude`                      |
| **Min macOS**   | 14.0 (Sonoma)                            |

---

## Project Structure

```
ponude-app/
├── Package.swift                    # SPM manifest (executable target, macOS 14+)
├── build_app.sh                     # Shell script: builds release + creates .app bundle
├── AppIcon.png                      # Source icon (auto-converted to .icns)
│
├── Ponude/                          # ── Source root ──
│   ├── PonudaApp.swift              # @main App entry, WindowGroup + Settings scene
│   ├── ContentView.swift            # Root NavigationSplitView (sidebar + detail)
│   │
│   ├── Models/                      # ── SwiftData @Model definitions ──
│   │   ├── BusinessProfile.swift    # Business entity that issues quotes
│   │   ├── Client.swift             # Client entity that receives quotes
│   │   └── Ponuda.swift             # Quote document + PonudaStavka line items
│   │
│   ├── ViewModels/                  # ── Observable state objects ──
│   │   └── QuoteBuilderViewModel.swift  # QuoteBuilderState + StavkaEditItem
│   │
│   ├── Views/                       # ── SwiftUI views (grouped by feature) ──
│   │   ├── Builder/
│   │   │   ├── QuoteBuilderView.swift   # Split-pane editor + live preview
│   │   │   ├── QuotePreviewView.swift   # Pixel-perfect A4 paper simulation
│   │   │   └── ServiceItemRow.swift     # Single line-item editor row
│   │   │
│   │   ├── Dashboard/
│   │   │   └── DashboardView.swift      # Quote list, stats cards, search/filter
│   │   │
│   │   ├── Clients/
│   │   │   ├── ClientListView.swift     # Full client CRUD management
│   │   │   └── ClientSelectorView.swift # Sheet: pick client (local + Sudreg)
│   │   │
│   │   └── Settings/
│   │       ├── SettingsView.swift        # macOS Settings window (⌘,)
│   │       └── BusinessProfileEditor.swift  # Create/edit business profiles
│   │
│   ├── Services/                    # ── Business logic & external APIs ──
│   │   ├── PDFGenerator.swift       # HTML→PDF via WebKit, NSSavePanel export
│   │   └── SudregService.swift      # OAuth2 + REST client for court register
│   │
│   ├── Helpers/                     # ── Shared utilities ──
│   │   └── Extensions.swift         # Color(hex:), DesignTokens, HR formatting
│   │
│   └── Resources/                   # ── Bundled resources ──
│       └── quote_template.html      # Placeholder (actual HTML in PDFGenerator)
│
├── build/                           # Build output (.app bundle)
└── .build/                          # SPM build cache
```

---

## Architecture Overview

The app follows a **lightweight MVVM** pattern on top of SwiftData:

```
┌─────────────────────────────────────────────────────────┐
│                     PonudaApp (@main)                    │
│  WindowGroup → ContentView   |   Settings → SettingsView │
│  ModelContainer: [BusinessProfile, Client, Ponuda, ...]  │
└──────────────────────┬──────────────────────────────────┘
                       │
          ┌────────────┼────────────────┐
          │            │                │
    DashboardView  QuoteBuilderView  ClientListView
          │            │                │
          │     QuoteBuilderState       │
          │     (Observable ViewModel)  │
          │            │                │
          │     ┌──────┴──────┐         │
          │     │             │         │
    QuotePreviewView   PDFGenerator    SudregService
    (SwiftUI render)   (HTML→PDF)      (OAuth2 REST)
          │
    ┌─────┴─────┐
    │ SwiftData  │
    │ @Model     │
    └────────────┘
```

### Key design decisions:

- **SwiftData** is used for all persistence (no CoreData, no JSON files)
- **No external dependencies** — zero third-party packages
- **PDF generation** uses WebKit's `createPDF()` on a hidden `WKWebView`, rendering a fully-styled HTML document
- **The preview** is a pure SwiftUI recreation of the same layout (not a WebView) for responsive, real-time updates during editing
- **Sudreg integration** uses OAuth2 Client Credentials flow; credentials are stored in `UserDefaults` / `@AppStorage`

---

## Data Model (SwiftData)

All models use the `@Model` macro for automatic SwiftData persistence.

### `BusinessProfile`

> **File:** `Models/BusinessProfile.swift`

The issuing business entity. Supports multiple profiles (multi-company).

| Property         | Type      | Description                                      |
|------------------|-----------|--------------------------------------------------|
| `name`           | `String`  | Full trade name, e.g. "Lotus RC, vl. Timon Terzić" |
| `shortName`      | `String`  | Brand name for display, e.g. "Lotus RC"          |
| `ownerName`      | `String`  | Owner name                                       |
| `oib`            | `String`  | Croatian tax ID (OIB)                            |
| `iban`           | `String`  | Bank account                                     |
| `address`        | `String`  | Street address                                   |
| `city`           | `String`  | City                                             |
| `zipCode`        | `String`  | Postal code                                      |
| `phone`          | `String`  | Contact phone                                    |
| `email`          | `String`  | Contact email                                    |
| `website`        | `String`  | Website URL                                      |
| `taxStatusRaw`   | `String`  | Raw value of `TaxStatus` enum                    |
| `vatExemptNote`  | `String`  | Legal note for VAT exemption on PDF              |
| `brandColorHex`  | `String`  | Hex color for PDF/UI accents (default: `#C5A55A`)|
| `logoData`       | `Data?`   | Optional logo (stored as external binary)        |
| `isDefault`      | `Bool`    | Whether this is the default profile              |
| `createdAt`      | `Date`    | Creation timestamp                               |

**Relationships:** `ponude: [Ponuda]` (cascade delete)

**Enum — `TaxStatus`:** `pausalnObrt` | `uSustavuPDV` | `slobodnoZanimanje`

---

### `Client`

> **File:** `Models/Client.swift`

The quote recipient. Can be created manually or auto-populated from Sudreg API.

| Property         | Type      | Description                |
|------------------|-----------|----------------------------|
| `name`           | `String`  | Company/entity name        |
| `oib`            | `String`  | Croatian tax ID            |
| `mbs`            | `String`  | Sudreg subject ID          |
| `address`        | `String`  | Street address             |
| `city`           | `String`  | City                       |
| `zipCode`        | `String`  | Postal code                |
| `contactPerson`  | `String`  | Contact name               |
| `email`          | `String`  | Email                      |
| `phone`          | `String`  | Phone                      |
| `notes`          | `String`  | Free-text notes            |
| `createdAt`      | `Date`    | Creation timestamp         |

**Relationships:** `ponude: [Ponuda]` (nullify on delete)

**Computed:** `fullAddress`, `displayName`

---

### `Ponuda` + `PonudaStavka`

> **File:** `Models/Ponuda.swift`

The quote document and its line items.

#### Ponuda (Quote)

| Property          | Type              | Description                          |
|-------------------|-------------------|--------------------------------------|
| `broj`            | `Int`             | Sequential quote number              |
| `datum`           | `Date`            | Issue date                           |
| `mjesto`          | `String`          | Location/city of issuance            |
| `rokValjanosti`   | `Int`             | Validity in days                     |
| `napomena`        | `String`          | Additional notes                     |
| `statusRaw`       | `String`          | Raw value of `PonudaStatus`          |
| `createdAt`       | `Date`            | Creation timestamp                   |
| `updatedAt`       | `Date`            | Last update timestamp                |

**Relationships:** `businessProfile: BusinessProfile?`, `client: Client?`, `stavke: [PonudaStavka]` (cascade)

**Enum — `PonudaStatus`:** `nacrt` (Draft) → `poslano` (Sent) → `prihvaceno` (Accepted) / `odbijeno` (Rejected)

#### PonudaStavka (Line Item)

| Property      | Type      | Description              |
|---------------|-----------|--------------------------|
| `redniBroj`   | `Int`     | Order index (1-based)    |
| `naziv`       | `String`  | Service/product name     |
| `opis`        | `String`  | Description (sub-line)   |
| `kolicina`    | `Decimal` | Quantity                 |
| `cijena`      | `Decimal` | Unit price in EUR        |

**Computed:** `vrijednost` (quantity × price), formatted versions

---

## Views & Navigation

### App Entry — `PonudaApp.swift`

- Declares `WindowGroup` with `ContentView` and a `Settings` scene with `SettingsView`
- Registers `ModelContainer` for all four model types
- Default window size: `1280 × 800`
- Adds `⌘N` shortcut via `CommandGroup` to create a new quote

### Root — `ContentView.swift`

A `NavigationSplitView` with:

- **Sidebar:** Business profile picker (if multiple profiles exist) + navigation links for Dashboard, Clients
- **Detail pane:** Switches between `DashboardView`, `ClientListView`, or `QuoteBuilderView`
- On first launch, auto-creates a default "Lotus RC" business profile

**Navigation enum:** `.dashboard` | `.clients` | `.newQuote`

### Dashboard — `DashboardView.swift`

- **Stats cards:** Total value, total count, drafts, sent, accepted
- **Filter tabs:** All / Nacrt / Poslano / Prihvaćeno / Odbijeno
- **Search:** By client name, quote number, or location
- **Quote list:** Sortable table with hover effects, click-to-edit, delete with confirmation
- Scoped to the currently selected business profile

**Sub-views:** `StatCard`, `FilterTab`, `QuoteRow`

### Quote Builder — `QuoteBuilderView.swift`

A **split-pane** layout:
- **Left panel (editor):** Client selector, quote details (number, date, location, validity), line items editor, notes, save/export actions
- **Right panel (preview):** Real-time `QuotePreviewView` rendering

**State management:** Uses `QuoteBuilderState` (Observable) for all editing state. String-based fields for text field binding, with computed `Decimal` properties for calculations.

**Save logic:** Creates or updates a `Ponuda` SwiftData model, replaces all `PonudaStavka` items. Shows a success toast.

### Quote Preview — `QuotePreviewView.swift`

A pixel-perfect **A4 paper simulation** (595 × 842 pt) built entirely in SwiftUI:
- Dark header band with brand name
- Gold "PONUDA" title with horizontal rules
- Two-column issuer/client section
- Quote metadata (number, date, location)
- Typeset table with quantity × price = total
- Totals section
- Dark footer with website and tax status

Scales responsively using `GeometryReader` to fit the available space.

### Service Item Row — `ServiceItemRow.swift`

A single line-item editor:
- Index number, service name field, expandable description
- Quantity × Price = Total display (monospaced, gold-colored)
- Hover-reveal delete button
- Focus state management across fields

### Client List — `ClientListView.swift`

Full CRUD for clients:
- Search by name, OIB, or city
- Table with avatar, name, OIB, city, quote count
- Edit/delete actions on hover
- "Novi klijent" button opens `ManualClientForm`

**Sub-views:** `ClientManagementRow`

### Client Selector — `ClientSelectorView.swift`

Presented as a **sheet** from the quote builder:
- Local search over saved clients
- "Traži online" button triggers Sudreg API search
- Sudreg results appear in a separate section; selecting one auto-saves to local DB
- "Dodaj ručno" opens `ManualClientForm`

**Sub-views:** `ClientRow`, `NewClientData`, `ManualClientForm`

### Settings — `SettingsView.swift`

macOS native Settings window (⌘,) with three tabs:

| Tab          | Content                                               |
|--------------|-------------------------------------------------------|
| **Tvrtke**   | List of business profiles, add/edit/delete             |
| **Sudreg API** | Client ID / Secret fields, connection test, registration link |
| **Zadano**   | Default location, validity period, app version info    |

### Business Profile Editor — `BusinessProfileEditor.swift`

A form sheet for creating/editing profiles:
- Company info, identification (OIB, IBAN), address, contact
- Tax status picker (Paušalni obrtnik / U sustavu PDV-a / Slobodno zanimanje)
- Brand color picker (8 preset swatches)
- Default profile toggle

---

## Services

### `PDFGenerator.swift`

Generates professional A4 PDFs using WebKit:

1. **Builds a complete HTML document** with inline CSS matching the reference design
2. **Loads it into a hidden `WKWebView`** (595 × 842 px frame)
3. **Calls `createPDF(configuration:)`** with A4 dimensions
4. **Saves via `NSSavePanel`** and auto-opens the result

Key details:
- Filename format: `{broj}-Ponuda_{yyyyMMdd_HHmmss}.pdf`
- Uses system fonts (`-apple-system`, `Georgia` for serif headers, `SF Mono` for numbers)
- HTML escaping via `escapeHTML()` for safe rendering
- Brand name splitting logic (`splitBrandName`) for elegant header layout

### `SudregService.swift`

Queries the Croatian Court Register API (`sudreg-data.gov.hr`):

1. **OAuth2 Client Credentials** flow: fetches `access_token` via Basic Auth
2. **Subject search**: by company name (`tvrtka_naziv`) or OIB (11-digit detection)
3. **Token management**: auto-refreshes with 60-second buffer
4. **Response parsing**: handles multiple JSON structures with graceful fallbacks

Credentials stored in `UserDefaults`:
- `sudregClientId`
- `sudregClientSecret`

---

## Helpers & Design System

### `Extensions.swift`

#### `Color(hex:)`
Initializes SwiftUI `Color` from a hex string. Handles 3, 6, and 8-character formats.

#### `DesignTokens`
Centralized color palette:

| Token              | Hex       | Usage                          |
|--------------------|-----------|--------------------------------|
| `gold`             | `#C5A55A` | Primary accent, buttons, brand |
| `dark`             | `#1A1A1A` | Header/footer backgrounds      |
| `textPrimary`      | `#333333` | Main text                      |
| `textSecondary`    | `#888888` | Secondary labels               |
| `lineColor`        | `#CCCCCC` | Dividers, rules                |
| `cardBackground`   | `#F8F8F8` | Card surfaces                  |
| `pageBackground`   | `#ECECEC` | Preview area background        |
| `statusDraft`      | `#94A3B8` | Nacrt badge                    |
| `statusSent`       | `#3B82F6` | Poslano badge                  |
| `statusAccepted`   | `#22C55E` | Prihvaćeno badge               |
| `statusRejected`   | `#EF4444` | Odbijeno badge                 |

#### `Decimal.hrFormatted`
Croatian number formatting: `30.000,00` (dot as thousands separator, comma as decimal).

#### `String.toDecimal`
Reverse parser: converts Croatian-formatted string to `Decimal`.

#### `Date.hrFormatted`
Croatian date format: `09.04.2026.`

#### `GoldDivider` / `ThinDivider`
Reusable divider views with design-system colors.

---

## Build & Run

### Development (debug)

```bash
cd ponude-app
swift build
swift run Ponude
```

### Production (.app bundle)

```bash
cd ponude-app
./build_app.sh
```

This script:
1. Runs `swift build -c release`
2. Creates a `.app` bundle structure in `build/Ponude.app`
3. Generates `Info.plist` with proper bundle config
4. Converts `AppIcon.png` → `AppIcon.icns` using `sips` + `iconutil`
5. Launches the app automatically

---

## Key Workflows

### Creating a Quote

1. User selects a business profile in the sidebar
2. Clicks "Nova ponuda" (or ⌘N)
3. `QuoteBuilderView` appears with split editor/preview
4. User selects a client (local or via Sudreg search)
5. Fills in line items — preview updates in real-time
6. Clicks "Spremi" → saved to SwiftData
7. Clicks "Izvezi PDF" → generates HTML, renders via WebKit, saves to disk

### Adding a Client from Sudreg

1. In `ClientSelectorView`, user types a company name
2. Clicks "Traži online"
3. `SudregService` authenticates via OAuth2, queries `/api/javni/subjekti`
4. Results displayed in "Sudski registar" section
5. Selecting a result creates a `Client` model with all fields auto-filled
6. Duplicate detection via OIB match

### Multi-Company Support

1. Multiple `BusinessProfile` instances stored in SwiftData
2. Sidebar shows a profile picker when `profiles.count > 1`
3. Dashboard and quote builder are scoped to the selected profile
4. Each profile has its own brand color, reflected in the PDF output

---

## Configuration & Settings

| Setting               | Storage          | Key                     | Default                    |
|-----------------------|------------------|-------------------------|----------------------------|
| Sudreg Client ID      | `UserDefaults`   | `sudregClientId`        | `""`                       |
| Sudreg Client Secret  | `UserDefaults`   | `sudregClientSecret`    | `""`                       |
| Default Location      | `@AppStorage`    | `defaultMjesto`         | `""`                       |
| Default Validity      | `@AppStorage`    | `defaultRokValjanosti`  | `30` days                  |

---

## File-by-File Reference

| File | Lines | Purpose |
|------|-------|---------|
| `Package.swift` | 17 | SPM manifest — defines `Ponude` executable target for macOS 14+ |
| `build_app.sh` | 98 | Release build script — compiles, bundles .app, generates icon |
| `PonudaApp.swift` | 39 | `@main` entry — WindowGroup, Settings scene, ModelContainer, ⌘N shortcut |
| `ContentView.swift` | 173 | Root `NavigationSplitView` — sidebar navigation, profile picker, detail routing |
| `BusinessProfile.swift` | 87 | `@Model` — business entity with branding, tax, and contact info |
| `Client.swift` | 66 | `@Model` — quote recipient with Sudreg integration fields |
| `Ponuda.swift` | 126 | `@Model` — quote document + `PonudaStavka` line items + status workflow |
| `QuoteBuilderViewModel.swift` | 123 | `@Observable` — editing state with String↔Decimal bridging |
| `QuoteBuilderView.swift` | 411 | Split-pane quote editor — form + live preview + save/export |
| `QuotePreviewView.swift` | 469 | Pixel-perfect A4 SwiftUI simulation — header, table, totals, footer |
| `ServiceItemRow.swift` | 127 | Single line-item editor — name, description, quantity × price |
| `DashboardView.swift` | 350 | Quote dashboard — stats, filters, searchable list, CRUD |
| `ClientListView.swift` | 248 | Client management — table, search, edit/delete, manual add |
| `ClientSelectorView.swift` | 371 | Sheet — local + Sudreg search, auto-save, manual form |
| `SettingsView.swift` | 218 | macOS Settings — profiles tab, Sudreg API tab, defaults tab |
| `BusinessProfileEditor.swift` | 195 | Form sheet — create/edit profiles with color picker |
| `PDFGenerator.swift` | 455 | HTML→PDF engine — builds styled HTML, renders via WebKit |
| `SudregService.swift` | 212 | OAuth2 REST client — Croatian Court Register API |
| `Extensions.swift` | 104 | Color(hex:), DesignTokens, HR number/date formatting, dividers |
| `quote_template.html` | 12 | Placeholder resource (actual template in PDFGenerator.swift) |

---

*Last updated: April 13, 2026*
