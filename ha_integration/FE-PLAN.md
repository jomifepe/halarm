# HAlarm — HA Frontend Panel: Implementation Plan

## Purpose

HAlarm is a native iOS app for managing Home Assistant blind automations. It talks to a custom HA integration (`custom_components/halarm`) via REST. The goal of this task is to add a **Home Assistant sidebar panel** — a web UI built into HA itself — that provides the same functionality as the iOS app. This means users can create, edit, delete, and toggle blind alarms directly from the HA web interface or the HA Companion app, without needing a phone. Both clients (iOS and web panel) will share the same backend integration and automation format.

---

## 1. Backend Changes

### 1.1 `manifest.json` — add `"frontend"` dependency

```json
"dependencies": ["http", "frontend"]
```

### 1.2 `__init__.py` — register static files and sidebar panel

Add alongside the existing `register_view` call:

```python
from homeassistant.components.frontend import async_register_panel
from homeassistant.components.http import StaticPathConfig
import pathlib

FRONTEND_DIST = pathlib.Path(__file__).parent / "frontend" / "dist"

async def async_setup(hass, config):
    await hass.http.async_register_static_paths([
        StaticPathConfig("/halarm_static", str(FRONTEND_DIST), cache_headers=False)
    ])
    async_register_panel(
        hass,
        component_name="halarm",
        sidebar_title="HAlarm",
        sidebar_icon="mdi:alarm",
        frontend_url_path="halarm",
        require_admin=False,
        js_url="/halarm_static/halarm-panel.js",
    )
    hass.http.register_view(HAlarmAutomationsView())
    return True
```

### 1.3 `http.py` — no changes needed

The current `http.py` handles `GET /api/halarm/automations`. For CRUD, the frontend calls HA's built-in REST endpoints (`/api/config/automation/config/{id}`) directly via `hass.callApi`. Only the list endpoint is custom.

---

## 2. Frontend File Structure

```
ha_integration/custom_components/halarm/frontend/
├── package.json
├── tsconfig.json
├── vite.config.ts
└── src/
    ├── types.ts              ← shared interfaces
    ├── halarm-panel.ts       ← root custom element, view router
    ├── alarm-list.ts         ← alarm list view
    ├── alarm-form.ts         ← create/edit form view
    └── weekday-picker.ts     ← reusable weekday toggle row
```

Output: `dist/halarm-panel.js` (single IIFE bundle, ~60–100 KB)

---

## 3. Build Tooling

### `package.json`

```json
{
  "name": "halarm-panel",
  "private": true,
  "scripts": {
    "build": "vite build",
    "dev": "vite build --watch"
  },
  "devDependencies": {
    "lit": "^3.0.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0"
  }
}
```

### `tsconfig.json`

Standard config: `"target": "ES2020"`, `"useDefineForClassFields": false` (required for Lit decorators), strict mode on.

### `vite.config.ts`

Builds as IIFE (immediately-invoked function expression) — required for HA panels:
```ts
build: {
  lib: {
    entry: "src/halarm-panel.ts",
    formats: ["iife"],
    name: "HAlarmPanel",
    fileName: () => "halarm-panel.js",
  },
  rollupOptions: {
    // Lit is bundled in (HA doesn't expose it globally)
  }
}
```

---

## 4. TypeScript Types (`types.ts`)

```ts
export interface Alarm {
  id: string;
  label: string;
  hour: number;
  minute: number;
  weekdays: string[];   // ["mon","tue",...]
  isEnabled: boolean;
  deviceId: string;
  deviceName: string;
  position: number;     // 0–100
}

export interface CoverEntity {
  entity_id: string;
  friendly_name: string;
}

export interface HAAutomation {
  id: string;
  alias: string;
  description: string;
  trigger: unknown[];
  condition: unknown[];
  action: unknown[];
  mode: string;
}
```

---

## 5. Root Panel (`halarm-panel.ts`)

The root Lit element is registered as `<halarm-panel>`. HA injects a `hass` property (the HA frontend object) and a `panel` property automatically.

**Responsibilities:**
- Owns top-level routing state: `"list" | "create" | { edit: Alarm }`
- Owns alarm list state: `alarms: Alarm[]`, `loading`, `error`
- Fetches alarms on connect via `hass.callApi("GET", "halarm/automations")`
- Fetches cover entities via `hass.callApi("GET", "states")` filtered to `cover.*`
- Passes data and callbacks down to child views
- Renders HA's `<ha-card>` wrapper and top `<app-toolbar>` for consistent HA chrome

**Key HA APIs used:**
- `this.hass.callApi(method, path, data?)` — authenticated fetch, returns parsed JSON
- `this.hass.callService(domain, service, data)` — for toggle on/off

**View routing:** A simple property switch — no external router needed:
```ts
render() {
  if (this.view === "list") return html`<alarm-list ...>`;
  if (this.view === "create") return html`<alarm-form ...>`;
  if (this.view?.edit) return html`<alarm-form .alarm=${this.view.edit} ...>`;
}
```

---

## 6. Alarm List View (`alarm-list.ts`)

Displays alarms with:
- Each row: time (large), label, weekday summary, position, enabled toggle
- Delete button per row
- "Add alarm" button in header
- "Shift all" button → inline ±minutes input

**CRUD callbacks (passed from root):**
- `onAdd()` → root switches to create view
- `onEdit(alarm)` → root switches to edit view
- `onDelete(id)` → calls `hass.callApi("DELETE", "config/automation/config/${id}")`
- `onToggle(alarm, enabled)` → calls `hass.callService("automation", enabled ? "turn_on" : "turn_off", { entity_id: "automation." + id })`
- `onShift(minutes)` → loops all alarms, calls update for each

**Weekday display logic** (mirrors iOS):
- All 7 → "Every day"
- Mon–Fri → "Weekdays"
- Sat–Sun → "Weekends"
- Otherwise → "Mon, Tue, Wed"

---

## 7. Alarm Form (`alarm-form.ts`)

Used for both create and edit. Accepts optional `alarm` prop (edit mode) or nothing (create mode).

**Fields:**

| Field | HA Component | Fallback |
|---|---|---|
| Time | `<ha-time-input>` | `<input type="time">` |
| Label | `<ha-textfield>` | `<input type="text">` |
| Weekdays | `<weekday-picker>` | custom |
| Device | `<ha-entity-picker domain="cover">` | filtered `<select>` |
| Position | `<ha-slider>` | `<input type="range">` |

**Create multiple alarms toggle** (matches iOS feature):
- Toggle: "Create multiple alarms"
- When on: count stepper, interval (minutes), direction (open/close), position increment

**Save logic:**
- Build `HAAutomation` object from form state (mirrors `AutomationMapper.toHA`)
- If create: `hass.callApi("POST", "config/automation/config/${uuid()}")`
- If edit: `hass.callApi("POST", "config/automation/config/${alarm.id}")`
- On success: call `onSaved()` callback → root reloads list and returns to list view

**Automation structure written** (must match iOS `AutomationMapper` format exactly so both clients are compatible):
```json
{
  "alias": "<label>",
  "description": "{\"label\":\"...\",\"deviceId\":\"...\",\"deviceName\":\"...\",\"position\":75,\"weekdays\":[...]}",
  "trigger": [{"trigger": "time", "at": "08:00:00"}],
  "condition": [{"condition": "time", "weekday": ["mon","tue",...]}],
  "action": [{"action": "cover.set_cover_position", "target": {"entity_id": "cover.xxx"}, "data": {"position": 75}}],
  "mode": "single"
}
```
- Condition omitted when all 7 weekdays selected (same as iOS)

---

## 8. Weekday Picker (`weekday-picker.ts`)

Reusable Lit component. Accepts `weekdays: string[]` and emits `weekdays-changed` CustomEvent.

Seven pill buttons: Mon Tue Wed Thu Fri Sat Sun. Selected = HA blue (`--primary-color`), unselected = gray. Clicking toggles the day in the array.

---

## 9. Styling

- Use HA CSS variables throughout: `--primary-color`, `--primary-text-color`, `--secondary-text-color`, `--card-background-color`, `--divider-color`
- Dark/light mode handled automatically — no media queries needed
- Use `<ha-card>` for card chrome, `<mwc-list>` or plain `<ul>` for alarm list rows
- Toolbar: `<app-toolbar>` + title + action buttons

---

## 10. Feature Checklist

| Feature | iOS | Panel |
|---|---|---|
| List alarms | ✅ | ✅ |
| Enable/disable toggle | ✅ | ✅ |
| Create alarm | ✅ | ✅ |
| Edit alarm | ✅ | ✅ |
| Delete alarm | ✅ | ✅ |
| Weekday selection | ✅ | ✅ |
| Device picker | ✅ | ✅ (native `ha-entity-picker`) |
| Position slider | ✅ | ✅ |
| Create multiple alarms | ✅ | ✅ |
| Shift all alarms | ✅ | ✅ |
| Remember last config | ✅ | ✅ (localStorage) |
| Dark mode | ✅ | ✅ (automatic via HA theme) |
| Offline / error states | ✅ | ✅ |

---

## 11. Files to Create / Modify

| File | Action |
|---|---|
| `ha_integration/custom_components/halarm/manifest.json` | Edit: add `"frontend"` to dependencies |
| `ha_integration/custom_components/halarm/__init__.py` | Edit: add static path + panel registration |
| `ha_integration/custom_components/halarm/frontend/package.json` | Create |
| `ha_integration/custom_components/halarm/frontend/tsconfig.json` | Create |
| `ha_integration/custom_components/halarm/frontend/vite.config.ts` | Create |
| `ha_integration/custom_components/halarm/frontend/src/types.ts` | Create |
| `ha_integration/custom_components/halarm/frontend/src/halarm-panel.ts` | Create |
| `ha_integration/custom_components/halarm/frontend/src/alarm-list.ts` | Create |
| `ha_integration/custom_components/halarm/frontend/src/alarm-form.ts` | Create |
| `ha_integration/custom_components/halarm/frontend/src/weekday-picker.ts` | Create |

`http.py` — no changes needed. `dist/` — generated by `npm run build`, not committed.

---

## 12. Install & Run

```bash
# One-time setup
cd ha_integration/custom_components/halarm/frontend
npm install

# Build
npm run build   # outputs dist/halarm-panel.js

# Deploy
cp -r ha_integration/custom_components/halarm/ ~/.homeassistant/custom_components/halarm/
# Restart Home Assistant
# → HAlarm icon appears in sidebar
```
