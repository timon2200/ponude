# Ponude MCP — letting agents create quotes

Ponude ships an **MCP server** so AI agents (Claude Code, Claude Desktop, or any
other MCP client) can look up clients and create quotes in the app.

---

## How it fits together

```
  MCP client                ponude-mcp                    Ponude.app
  (Claude, …)  ──stdio──▶   (bridge, no state)  ──HTTP──▶  LocalAPIServer
                              JSON-RPC 2.0        127.0.0.1   │
                                                              ▼
                                                       SwiftData store
```

`ponude-mcp` is a thin translator. It holds no data and never opens the
database. Every call goes into the **running app**, which performs the write on
its own `mainContext` through `Persistence.save`.

That indirection is the whole point:

- **One writer.** The SQLite store keeps a single owner. A standalone MCP server
  writing to `ponude.sqlite` behind the app's back would race with the app's own
  context and risk exactly the kind of loss the store is hardened against.
- **The UI stays live.** A quote an agent creates shows up in the dashboard
  immediately, because it was inserted into the context the views observe.
- **Failures are visible.** Writes go through the same logged save path as the
  builder, so a failed save is reported rather than silently swallowed.

The trade-off: **the app must be running.** With Ponude closed, every tool call
returns "The Ponude app is not running".

---

## Setup

1. Open **Ponude → Settings (⌘,) → Agenti**.
2. Switch on **"Dopusti agentima izradu ponuda"**. The status dot turns green.
3. Click **Kopiraj naredbu** and run it in a terminal:

   ```bash
   claude mcp add ponude -- /Applications/Ponude.app/Contents/MacOS/ponude-mcp
   ```

   For a client that uses a JSON config file, **Kopiraj MCP konfiguraciju**
   gives the equivalent block:

   ```json
   {
     "mcpServers": {
       "ponude": {
         "command": "/Applications/Ponude.app/Contents/MacOS/ponude-mcp",
         "env": { "PONUDE_API_URL": "http://127.0.0.1:8765" }
       }
     }
   }
   ```

No token needs to go into the config — the bridge reads it from
`~/Library/Application Support/hr.lotusrc.ponude/api-token.txt` (mode 0600),
which the app writes when you enable the server.

### Environment variables

| Variable            | Default                     | Purpose                                  |
|---------------------|-----------------------------|------------------------------------------|
| `PONUDE_API_URL`    | `http://127.0.0.1:8765`     | Where the app is listening.              |
| `PONUDE_API_TOKEN`  | read from `api-token.txt`   | Overrides the token file when set.       |

---

## Tools

| Tool                     | What it does                                                        |
|--------------------------|---------------------------------------------------------------------|
| `list_business_profiles` | The issuers. Decides quote numbering and PDF design.                 |
| `search_clients`         | Loose multi-word search — `"turis kop"` finds *Turistička zajednica grada Koprivnice*. |
| `create_client`          | Adds a client; returns the existing one instead of duplicating an OIB. |
| `create_ponuda`          | Creates the quote. Numbering is automatic per profile.               |
| `list_ponude`            | Existing quotes, newest number first.                                |
| `get_ponuda`             | One quote in full, with line items.                                  |
| `update_ponuda`          | Partial update — only the fields passed change; `stavke` replaces all line items. |
| `delete_ponuda`          | Deletes the quote and its line items. Permanent, no undo.            |
| `export_ponuda_pdf`      | Renders to PDF using the profile's design; returns the path.         |

A typical agent run:

```
list_business_profiles  →  search_clients("turis kop")  →  create_ponuda(…)  →  export_ponuda_pdf(id)
```

`create_ponuda` takes the profile by name (`"Lotus RC"`), the client by
`client_id` / `client_oib` / `client_name`, and a `stavke` array of
`{naziv, opis, kolicina, cijena}`. Amounts are EUR and no VAT is added — the
profiles are VAT-exempt. A `client_name` that matches more than one client is
rejected rather than guessed.

---

## Security

- The listener binds **127.0.0.1 only**. It is not reachable from the network,
  and the app's own build verifies this.
- Every route except `/health` needs the bearer token; comparison is
  constant-time.
- The token is 256 bits from the system CSPRNG, stored 0600. **Novi token** in
  Settings rotates it and invalidates every existing client.
- The server runs only while the app is open and the toggle is on. It is off by
  default.

An agent with the token can create, update, and delete quotes, create clients,
and write PDFs to paths it chooses. Deletion is permanent — agents should
confirm with the user before calling `delete_ponuda`, the same as they would
before any irreversible action.

---

## HTTP API

Useful for scripting without MCP. All routes need
`Authorization: Bearer <token>`, except `/health`.

| Method | Route                | Body / Query                                    |
|--------|----------------------|-------------------------------------------------|
| GET    | `/health`            | —                                               |
| GET    | `/profiles`          | —                                               |
| GET    | `/clients`           | `?q=` search terms                              |
| POST   | `/clients`           | `{name, oib?, address?, city?, zip_code?, …}`   |
| GET    | `/ponude`            | `?profile=`, `?limit=`                          |
| POST   | `/ponude`            | `{profile, client_*, stavke[], datum?, …}`      |
| GET    | `/ponude/{id}`       | —                                               |
| PUT    | `/ponude/{id}`       | Partial update — only the fields sent change; `stavke` replaces all line items. `PATCH` accepted too. |
| DELETE | `/ponude/{id}`       | Deletes the quote and its line items. Permanent. |
| POST   | `/ponude/{id}/pdf`   | `{path?}` — defaults to `~/Downloads`           |

```bash
TOKEN=$(cat ~/Library/Application\ Support/hr.lotusrc.ponude/api-token.txt)
curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8765/profiles
```

Ids are opaque strings (base64-encoded SwiftData `PersistentIdentifier`s) —
pass them back exactly as received.

---

## Source

| File                             | Role                                             |
|----------------------------------|--------------------------------------------------|
| `Ponude/Services/LocalAPIServer.swift` | Loopback listener + minimal HTTP parsing.   |
| `Ponude/Services/APIRouter.swift`      | Routes, store access, input parsing.        |
| `Ponude/Services/APIToken.swift`       | Token generation and storage.               |
| `Ponude/Views/Settings/MCPSettingsTab.swift` | The Settings pane and stored prefs.   |
| `PonudeMCP/main.swift`                 | The MCP stdio bridge (`ponude-mcp`).        |
