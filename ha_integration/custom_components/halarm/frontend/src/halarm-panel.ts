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

  @state() private _view: View = "list";
  @state() private _alarms: Alarm[] = [];
  @state() private _devices: CoverEntity[] = [];
  @state() private _loading = false;
  @state() private _error = "";

  static styles = css`
    :host {
      display: block;
      max-width: 680px;
      margin: 0 auto;
      padding: 16px;
      font-family: var(--paper-font-body1_-_font-family, sans-serif);
      color: var(--primary-text-color);
      box-sizing: border-box;
    }
  `;

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
    if (this._view === "create" || (typeof this._view === "object" && "edit" in this._view)) {
      return html`
        <alarm-form
          .hass=${this.hass}
          .alarm=${typeof this._view === "object" ? this._view.edit : null}
          .devices=${this._devices}
          @cancel=${() => { this._view = "list"; }}
          @saved=${this._handleSaved}
        ></alarm-form>
      `;
    }

    return html`
      <alarm-list
        .hass=${this.hass}
        .alarms=${this._alarms}
        .loading=${this._loading}
        .error=${this._error}
        @add=${() => { this._view = "create"; this._error = ""; }}
        @edit=${(e: CustomEvent) => { this._view = { edit: e.detail }; this._error = ""; }}
        @delete=${this._handleDelete}
        @toggle=${this._handleToggle}
        @shift=${this._handleShift}
      ></alarm-list>
    `;
  }
}
