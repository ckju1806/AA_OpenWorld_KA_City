# Toolchain (reproduzierbare Builds)

| Komponente | Version / Quelle | Prüfung |
|---|---|---|
| Godot-Editor (Linux x86_64) | 4.7.2.stable.official.ed1daf0bf – `github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip` | SHA512 gegen offizielle `SHA512-SUMS.txt`: OK (2026-09-23) |
| Export-Templates | 4.7.2.stable – `github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz` (offizielles Spiegel-Repo; im Hauptrepo lieferte GitHub am 2026-09-23 HTTP 500) | SHA512: OK (2026-09-23) |
| Verwendete Templates | `windows_release_x86_64.exe` (SHA256 `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562`), `windows_debug_x86_64.exe`, `*_console.exe` | installiert unter `~/.local/share/godot/export_templates/4.7.2.stable/` |
| Physik | Jolt Physics (in Godot 4.7 integriert) | – |
| Renderer | Forward+ (Vulkan/D3D12), Fallback OpenGL 3 | – |
| Python (nur Generatoren) | 3.11+, nur Standardbibliothek | – |

Windows-Pfad für Templates: `%APPDATA%\Godot\export_templates\4.7.2.stable\`.
