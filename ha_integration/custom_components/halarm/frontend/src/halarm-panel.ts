import { LitElement, html, css } from "lit";
import { customElement, property, state } from "lit/decorators.js";
import { Alarm, CoverEntity, HAState, HassObject } from "./types.js";
import "./alarm-list.js";
import "./alarm-form.js";

type View = "list" | "create" | { edit: Alarm };

function parseAlarm(raw: Record<string, unknown>, states: Record<string, HAState>): Alarm | null {
  try {
    const desc = raw["description"] as string | undefined;
    if (!desc) return null;
    const meta = JSON.parse(desc.replace(/\n/g, "").trim());
    if (!meta || !meta.label || !meta.deviceId || meta.position == null) return null;

    // Parse time from trigger (support both plural "triggers" and legacy singular "trigger")
    const triggers = (raw["triggers"] ?? raw["trigger"]) as Array<Record<string, unknown>> | undefined;
    const timeStr = triggers?.[0]?.["at"] as string | undefined;
    if (!timeStr) return null;
    const [hourStr, minuteStr] = timeStr.split(":");
    const hour = parseInt(hourStr);
    const minute = parseInt(minuteStr);
    if (isNaN(hour) || isNaN(minute)) return null;

    // Weekdays from metadata (primary) or condition (fallback)
    let weekdays: string[] = meta.weekdays ?? [];
    if (!weekdays.length) {
      // Support both plural "conditions" and legacy singular "condition"
      const conditions = (raw["conditions"] ?? raw["condition"]) as Array<Record<string, unknown>> | undefined;
      const timeCond = conditions?.find((c) => c["condition"] === "time");
      if (timeCond?.["weekday"]) weekdays = timeCond["weekday"] as string[];
      if (!weekdays.length) weekdays = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]; // no condition = every day
    }

    const id = raw["id"] as string;

    // Resolve enabled state from live hass.states by matching automation config id
    const entityState = Object.values(states).find(
      (s) => s.entity_id.startsWith("automation.") && s.attributes["id"] === id
    );
    const isEnabled = entityState ? entityState.state !== "off" : true;

    return {
      id,
      label: meta.label,
      hour,
      minute,
      weekdays,
      isEnabled,
      deviceId: meta.deviceId,
      deviceName: meta.deviceName ?? "",
      position: meta.position,
    };
  } catch {
    return null;
  }
}

@customElement("halarm-panel")
export class HalarmPanel extends LitElement {
  @property({ attribute: false }) hass!: HassObject;
  @property({ attribute: false }) panel: unknown;
  @property({ type: Boolean }) narrow = false;

  @state() private _view: View = "list";
  @state() private _alarms: Alarm[] = [];
  @state() private _devices: CoverEntity[] = [];
  @state() private _loading = false;
  @state() private _error = "";
  @state() private _shiftOpen = false;

  static styles = css`
    :host {
      display: block;
      height: 100%;
      font-family: var(--paper-font-body1_-_font-family, sans-serif);
      color: var(--primary-text-color);
      box-sizing: border-box;
    }

    .toolbar {
      display: flex;
      align-items: center;
      height: var(--header-height, 56px);
      padding: 0 4px;
      background: var(--app-header-background-color, var(--primary-color));
      color: var(--app-header-text-color, #fff);
      box-sizing: border-box;
      font-weight: 400;
      position: sticky;
      top: 0;
      z-index: 2;
    }

    .toolbar .icon-btn {
      background: none;
      border: none;
      cursor: pointer;
      color: inherit;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      font-size: 24px;
      line-height: 1;
      margin: 0 4px;
    }
    .toolbar .icon-btn:hover {
      background: rgba(255, 255, 255, 0.1);
    }
    .toolbar .icon-btn.active {
      background: rgba(255, 255, 255, 0.22);
    }
    .toolbar .icon-btn svg {
      width: 24px;
      height: 24px;
    }
    /* Filled glyphs (menu / back / add) use currentColor for their path fill.
       Stroked icons (like the Tabler shift icon) set fill="none" inline and
       must keep it; we scope the fill rule so we don't override them. */
    .toolbar .icon-btn svg.filled {
      fill: currentColor;
    }
    .toolbar .icon-btn svg.stroked {
      fill: none;
      stroke: currentColor;
    }

    .toolbar .title {
      flex: 1;
      font-size: 20px;
      font-weight: 400;
      margin: 0 8px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .content {
      max-width: 680px;
      margin: 0 auto;
      box-sizing: border-box;
    }
  `;

  private _toggleMenu() {
    this.dispatchEvent(
      new CustomEvent("hass-toggle-menu", { bubbles: true, composed: true })
    );
  }

  private _backToList() {
    this._view = "list";
    this._error = "";
  }

  private get _title(): string {
    if (this._view === "create") return "New Alarm";
    if (typeof this._view === "object" && "edit" in this._view) return "Edit Alarm";
    return "HAlarm";
  }

  connectedCallback() {
    super.connectedCallback();
    this._loadAll();
  }

  private async _loadAll() {
    this._loading = true;
    this._error = "";
    try {
      await Promise.all([this._fetchAlarms(), this._fetchDevices()]);
    } catch (err) {
      this._error = err instanceof Error ? err.message : "Failed to load data.";
    } finally {
      this._loading = false;
    }
  }

  private async _fetchAlarms() {
    const raw = await this.hass.callApi<Array<Record<string, unknown>>>("GET", "halarm/automations");
    this._alarms = raw.flatMap((a) => {
      const alarm = parseAlarm(a, this.hass.states);
      return alarm ? [alarm] : [];
    });
  }

  private async _fetchDevices() {
    const states = await this.hass.callApi<HAState[]>("GET", "states");
    this._devices = states
      .filter((s) => s.entity_id.startsWith("cover."))
      .map((s) => ({
        entity_id: s.entity_id,
        friendly_name: (s.attributes["friendly_name"] as string) ?? s.entity_id,
      }))
      .sort((a, b) => a.friendly_name.localeCompare(b.friendly_name));
  }

  private async _handleDelete(e: CustomEvent) {
    const id = e.detail as string;
    try {
      await this.hass.callApi("DELETE", `config/automation/config/${id}`);
      this._alarms = this._alarms.filter((a) => a.id !== id);
    } catch (err) {
      this._error = err instanceof Error ? err.message : "Failed to delete alarm.";
    }
  }

  private async _handleToggle(e: CustomEvent) {
    const { alarm, enabled } = e.detail as { alarm: Alarm; enabled: boolean };
    try {
      // Find the real entity_id by matching automation config id in hass.states
      const entityId = Object.keys(this.hass.states).find(
        (id) =>
          id.startsWith("automation.") &&
          this.hass.states[id].attributes["id"] === alarm.id
      );
      if (!entityId) throw new Error(`Could not find automation entity for id ${alarm.id}`);
      await this.hass.callService("automation", enabled ? "turn_on" : "turn_off", {
        entity_id: entityId,
      });
      this._alarms = this._alarms.map((a) =>
        a.id === alarm.id ? { ...a, isEnabled: enabled } : a
      );
    } catch (err) {
      this._error = err instanceof Error ? err.message : "Failed to toggle alarm.";
    }
  }

  private async _handleShift(e: CustomEvent) {
    const shiftMinutes = e.detail as number;
    this._error = "";
    for (const alarm of this._alarms) {
      const totalMinutes = ((alarm.hour * 60 + alarm.minute + shiftMinutes) % 1440 + 1440) % 1440;
      const newHour = Math.floor(totalMinutes / 60);
      const newMinute = totalMinutes % 60;
      const meta = JSON.stringify({
        label: alarm.label,
        deviceId: alarm.deviceId,
        deviceName: alarm.deviceName,
        position: alarm.position,
        weekdays: alarm.weekdays,
      });
      const allDays = alarm.weekdays.length === 7;
      const timeStr = `${String(newHour).padStart(2, "0")}:${String(newMinute).padStart(2, "0")}:00`;
      const automation = {
        alias: alarm.label,
        description: meta,
        triggers: [{ trigger: "time", at: timeStr }],
        conditions: allDays ? [] : [{ condition: "time", weekday: alarm.weekdays }],
        actions: [
          {
            action: "cover.set_cover_position",
            target: { entity_id: alarm.deviceId },
            data: { position: alarm.position },
          },
        ],
        mode: "single",
      };
      try {
        await this.hass.callApi("POST", `config/automation/config/${alarm.id}`, automation);
      } catch (err) {
        this._error = `Failed to shift alarm "${alarm.label}".`;
        break;
      }
    }
    await this._fetchAlarms();
  }

  private async _handleSaved() {
    this._view = "list";
    await this._fetchAlarms();
  }

  render() {
    const inSubView =
      this._view === "create" ||
      (typeof this._view === "object" && "edit" in this._view);

    const menuButton = html`
      <button
        class="icon-btn"
        aria-label="Open menu"
        @click=${this._toggleMenu}
      >
        <svg class="filled" viewBox="0 0 24 24">
          <path d="M3 6h18v2H3V6zm0 5h18v2H3v-2zm0 5h18v2H3v-2z" />
        </svg>
      </button>
    `;

    const backButton = html`
      <button
        class="icon-btn"
        aria-label="Back"
        @click=${this._backToList}
      >
        <svg class="filled" viewBox="0 0 24 24">
          <path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z" />
        </svg>
      </button>
    `;

    const shiftButton = html`
      <button
        class="icon-btn ${this._shiftOpen ? "active" : ""}"
        aria-label=${this._shiftOpen ? "Close shift" : "Shift all alarms"}
        title=${this._shiftOpen ? "Close shift" : "Shift all alarms"}
        @click=${() => { this._shiftOpen = !this._shiftOpen; }}
      >
        <svg class="stroked" width="20" height="20" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M9.95009 6.08796V10.088L11.9501 12.088M1.00009 9.08796C1.22418 6.88802 2.25036 4.84757 3.88282 3.35593C5.51529 1.86428 7.63979 1.02584 9.85097 1.00059C12.0622 0.975332 14.2052 1.76502 15.8714 3.21899C17.5375 4.67296 18.61 6.68944 18.8843 8.88369C19.1585 11.0779 18.6154 13.2964 17.3584 15.1157C16.1015 16.9351 14.2187 18.228 12.0694 18.7478C9.92001 19.2676 7.6545 18.9779 5.70509 17.934C3.75567 16.8901 2.25881 15.1651 1.50009 13.088M1.00009 18.088V13.088H6.00009" />
        </svg>
      </button>
    `;

    const addButton = html`
      <button
        class="icon-btn"
        aria-label="Add alarm"
        title="Add alarm"
        @click=${() => { this._view = "create"; this._error = ""; this._shiftOpen = false; }}
      >
        <svg class="filled" viewBox="0 0 24 24">
          <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z" />
        </svg>
      </button>
    `;

    return html`
      <div class="toolbar">
        ${inSubView ? backButton : menuButton}
        <div class="title">${this._title}</div>
        ${!inSubView ? html`${shiftButton}${addButton}` : ""}
      </div>

      <div class="content">
        ${inSubView
          ? html`
              <alarm-form
                .hass=${this.hass}
                .alarm=${typeof this._view === "object" ? this._view.edit : null}
                .devices=${this._devices}
                @cancel=${this._backToList}
                @saved=${this._handleSaved}
              ></alarm-form>
            `
          : html`
              <alarm-list
                .hass=${this.hass}
                .alarms=${this._alarms}
                .loading=${this._loading}
                .error=${this._error}
                .shiftOpen=${this._shiftOpen}
                @shift-close=${() => { this._shiftOpen = false; }}
                @edit=${(e: CustomEvent) => { this._view = { edit: e.detail }; this._error = ""; }}
                @delete=${this._handleDelete}
                @toggle=${this._handleToggle}
                @shift=${this._handleShift}
              ></alarm-list>
            `}
      </div>
    `;
  }
}
