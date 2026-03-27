import { LitElement, html, css } from "lit";
import { customElement, property, state } from "lit/decorators.js";
import { Alarm, CoverEntity, HAAutomation, HassObject } from "./types.js";
import "./weekday-picker.js";

const ALL_DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];

function zeroPad(n: number) { return String(n).padStart(2, "0"); }

function buildAutomation(
  id: string | undefined,
  label: string,
  hour: number,
  minute: number,
  weekdays: string[],
  deviceId: string,
  deviceName: string,
  position: number,
): HAAutomation {
  const meta = JSON.stringify({ label, deviceId, deviceName, position, weekdays });
  const timeStr = `${zeroPad(hour)}:${zeroPad(minute)}:00`;
  const allDays = weekdays.length === 7;

  const automation: HAAutomation = {
    alias: label,
    description: meta,
    triggers: [{ trigger: "time", at: timeStr }],
    conditions: allDays ? [] : [{ condition: "time", weekday: weekdays }],
    actions: [
      {
        action: "cover.set_cover_position",
        target: { entity_id: deviceId },
        data: { position },
      },
    ],
    mode: "single",
  };
  if (id) automation.id = id;
  return automation;
}

function generateId(): string {
  return "halarm_" + Math.random().toString(36).slice(2, 10);
}

const STORAGE_KEY = "halarm_last_config";

interface SavedConfig {
  label: string;
  hour: number;
  minute: number;
  weekdays: string[];
  position: number;
  deviceId: string;
  deviceName: string;
}

function loadLastConfig(): SavedConfig | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function saveLastConfig(cfg: SavedConfig) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(cfg));
  } catch { /* ignore */ }
}

@customElement("alarm-form")
export class AlarmForm extends LitElement {
  @property({ attribute: false }) hass!: HassObject;
  @property({ attribute: false }) alarm: Alarm | null = null;
  @property({ type: Array }) devices: CoverEntity[] = [];

  // Form state
  @state() private _label = "Blinds Alarm";
  @state() private _hour = 8;
  @state() private _minute = 0;
  @state() private _weekdays = [...ALL_DAYS];
  @state() private _deviceId = "";
  @state() private _deviceName = "";
  @state() private _position = 100;

  // Multiple alarms
  @state() private _createMultiple = false;
  @state() private _multipleCount = 2;
  @state() private _intervalMinutes = 15;
  @state() private _direction: "open" | "close" = "open";
  @state() private _positionIncrement = 10;

  @state() private _saving = false;
  @state() private _error = "";

  connectedCallback() {
    super.connectedCallback();
    if (this.alarm) {
      // Edit mode: populate from existing alarm
      this._label = this.alarm.label;
      this._hour = this.alarm.hour;
      this._minute = this.alarm.minute;
      this._weekdays = [...this.alarm.weekdays];
      this._deviceId = this.alarm.deviceId;
      this._deviceName = this.alarm.deviceName;
      this._position = this.alarm.position;
    } else {
      // Create mode: restore last config if available
      const last = loadLastConfig();
      if (last) {
        this._label = last.label;
        this._hour = last.hour;
        this._minute = last.minute;
        this._weekdays = last.weekdays;
        this._position = last.position;
        this._deviceId = last.deviceId;
        this._deviceName = last.deviceName;
      }
    }
  }

  static styles = css`
    :host { display: block; padding: 16px; }

    .header {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 20px;
    }
    .back-btn {
      background: none;
      border: none;
      cursor: pointer;
      font-size: 22px;
      color: var(--primary-color, #03a9f4);
      padding: 4px 8px;
      border-radius: 8px;
      line-height: 1;
    }
    h2 { margin: 0; font-size: 20px; font-weight: 600; }

    .section {
      background: var(--card-background-color, #fff);
      border-radius: 12px;
      padding: 16px;
      margin-bottom: 14px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.07);
    }
    .section-title {
      font-size: 11px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      color: var(--secondary-text-color);
      margin-bottom: 12px;
    }

    .field { margin-bottom: 12px; }
    .field:last-child { margin-bottom: 0; }
    label { display: block; font-size: 13px; color: var(--secondary-text-color); margin-bottom: 4px; }

    input[type=text], input[type=time], select {
      width: 100%;
      box-sizing: border-box;
      padding: 9px 12px;
      border: 1px solid var(--divider-color, #ddd);
      border-radius: 8px;
      background: var(--secondary-background-color, #f9f9f9);
      color: var(--primary-text-color);
      font-size: 15px;
    }

    .row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
    }
    .row label { margin: 0; }

    .toggle-switch {
      position: relative;
      width: 44px;
      height: 24px;
      flex-shrink: 0;
    }
    .toggle-switch input { opacity: 0; width: 0; height: 0; }
    .slider {
      position: absolute;
      inset: 0;
      background: var(--divider-color, #ccc);
      border-radius: 24px;
      transition: background 0.2s;
      cursor: pointer;
    }
    .slider:before {
      content: "";
      position: absolute;
      width: 18px; height: 18px;
      left: 3px; top: 3px;
      background: #fff;
      border-radius: 50%;
      transition: transform 0.2s;
    }
    .toggle-switch input:checked + .slider { background: var(--primary-color, #03a9f4); }
    .toggle-switch input:checked + .slider:before { transform: translateX(20px); }

    .stepper {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .stepper button {
      width: 32px; height: 32px;
      border-radius: 50%;
      border: none;
      background: var(--secondary-background-color, #e0e0e0);
      color: var(--primary-text-color);
      font-size: 18px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .stepper span { min-width: 28px; text-align: center; font-weight: 600; }

    .position-row { display: flex; align-items: center; gap: 10px; }
    .position-row input[type=range] { flex: 1; }
    .position-val { font-weight: 700; min-width: 42px; text-align: right; }

    .device-picker {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 12px;
      border: 1px solid var(--divider-color, #ddd);
      border-radius: 8px;
      background: var(--secondary-background-color, #f9f9f9);
      cursor: pointer;
    }
    .device-name { font-size: 15px; color: var(--primary-text-color); }
    .device-none { color: var(--secondary-text-color); }
    .device-chevron { color: var(--secondary-text-color); }

    .device-list {
      border: 1px solid var(--divider-color, #ddd);
      border-radius: 8px;
      overflow: hidden;
      margin-top: 8px;
    }
    .device-search {
      width: 100%;
      box-sizing: border-box;
      padding: 9px 12px;
      border: none;
      border-bottom: 1px solid var(--divider-color, #ddd);
      background: var(--card-background-color, #fff);
      color: var(--primary-text-color);
      font-size: 14px;
    }
    .device-options { max-height: 200px; overflow-y: auto; }
    .device-option {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 10px 14px;
      cursor: pointer;
      font-size: 14px;
    }
    .device-option:hover { background: var(--secondary-background-color, #f5f5f5); }
    .device-option.selected { color: var(--primary-color, #03a9f4); }
    .device-option-sub { font-size: 11px; color: var(--secondary-text-color); }

    .error { color: var(--error-color, #f44336); font-size: 13px; margin-top: 8px; }

    .save-btn {
      width: 100%;
      padding: 14px;
      background: var(--primary-color, #03a9f4);
      color: #fff;
      border: none;
      border-radius: 12px;
      font-size: 16px;
      font-weight: 700;
      cursor: pointer;
      margin-top: 8px;
    }
    .save-btn:disabled { opacity: 0.5; cursor: default; }
  `;

  @state() private _deviceSearchOpen = false;
  @state() private _deviceSearch = "";

  private get _filteredDevices(): CoverEntity[] {
    const q = this._deviceSearch.toLowerCase();
    if (!q) return this.devices;
    return this.devices.filter(
      (d) => d.entity_id.toLowerCase().includes(q) || d.friendly_name.toLowerCase().includes(q)
    );
  }

  private _selectDevice(device: CoverEntity) {
    this._deviceId = device.entity_id;
    this._deviceName = device.friendly_name;
    this._deviceSearchOpen = false;
    this._deviceSearch = "";
  }

  private async _save() {
    if (!this._deviceId) {
      this._error = "Please select a device.";
      return;
    }
    this._saving = true;
    this._error = "";

    // Persist last config
    saveLastConfig({
      label: this._label,
      hour: this._hour,
      minute: this._minute,
      weekdays: this._weekdays,
      position: this._position,
      deviceId: this._deviceId,
      deviceName: this._deviceName,
    });

    try {
      if (this.alarm) {
        // Edit: single update
        const automation = buildAutomation(
          this.alarm.id, this._label, this._hour, this._minute,
          this._weekdays, this._deviceId, this._deviceName, this._position
        );
        await this.hass.callApi("POST", `config/automation/config/${this.alarm.id}`, automation);
      } else if (this._createMultiple) {
        // Create multiple alarms
        const dir = this._direction === "close" ? -1 : 1;
        for (let i = 0; i < this._multipleCount; i++) {
          const totalMinutes = this._hour * 60 + this._minute + i * this._intervalMinutes;
          const h = Math.floor((totalMinutes % 1440) / 60);
          const m = totalMinutes % 60;
          const pos = Math.min(100, Math.max(0, this._position + i * dir * this._positionIncrement));
          const id = generateId();
          const automation = buildAutomation(
            id, this._label, h, m, this._weekdays, this._deviceId, this._deviceName, pos
          );
          await this.hass.callApi("POST", `config/automation/config/${id}`, automation);
        }
      } else {
        // Create single alarm
        const id = generateId();
        const automation = buildAutomation(
          id, this._label, this._hour, this._minute,
          this._weekdays, this._deviceId, this._deviceName, this._position
        );
        await this.hass.callApi("POST", `config/automation/config/${id}`, automation);
      }

      this.dispatchEvent(new CustomEvent("saved", { bubbles: true, composed: true }));
    } catch (err) {
      this._error = err instanceof Error ? err.message : "Failed to save alarm.";
    } finally {
      this._saving = false;
    }
  }

  private _back() {
    this.dispatchEvent(new CustomEvent("cancel", { bubbles: true, composed: true }));
  }

  render() {
    const isEdit = !!this.alarm;
    const timeValue = `${zeroPad(this._hour)}:${zeroPad(this._minute)}`;

    return html`
      <div class="header">
        <button class="back-btn" @click=${this._back}>‹</button>
        <h2>${isEdit ? "Edit Alarm" : "New Alarm"}</h2>
      </div>

      <!-- Alarm Details -->
      <div class="section">
        <div class="section-title">Alarm Details</div>
        <div class="field">
          <label>Label</label>
          <input
            type="text"
            .value=${this._label}
            @input=${(e: Event) => { this._label = (e.target as HTMLInputElement).value; }}
          />
        </div>
        <div class="field">
          <label>Time</label>
          <input
            type="time"
            .value=${timeValue}
            @change=${(e: Event) => {
              const [h, m] = (e.target as HTMLInputElement).value.split(":").map(Number);
              this._hour = h;
              this._minute = m;
            }}
          />
        </div>
      </div>

      <!-- Repeat -->
      <div class="section">
        <div class="section-title">Repeat</div>
        <weekday-picker
          .weekdays=${this._weekdays}
          @weekdays-changed=${(e: CustomEvent) => { this._weekdays = e.detail; }}
        ></weekday-picker>
      </div>

      <!-- Multiple Alarms (create only) -->
      ${!isEdit ? html`
        <div class="section">
          <div class="section-title">Multiple Alarms</div>
          <div class="row field">
            <label>Create multiple alarms</label>
            <label class="toggle-switch">
              <input type="checkbox" .checked=${this._createMultiple} @change=${(e: Event) => { this._createMultiple = (e.target as HTMLInputElement).checked; }} />
              <span class="slider"></span>
            </label>
          </div>
          ${this._createMultiple ? html`
            <div class="row field">
              <label>Count</label>
              <div class="stepper">
                <button @click=${() => { if (this._multipleCount > 2) this._multipleCount--; }}>−</button>
                <span>${this._multipleCount}</span>
                <button @click=${() => { if (this._multipleCount < 20) this._multipleCount++; }}>+</button>
              </div>
            </div>
            <div class="row field">
              <label>Interval (min)</label>
              <div class="stepper">
                <button @click=${() => { if (this._intervalMinutes > 1) this._intervalMinutes--; }}>−</button>
                <span>${this._intervalMinutes}</span>
                <button @click=${() => { if (this._intervalMinutes < 60) this._intervalMinutes++; }}>+</button>
              </div>
            </div>
            <div class="field">
              <label>Direction</label>
              <select .value=${this._direction} @change=${(e: Event) => { this._direction = (e.target as HTMLSelectElement).value as "open" | "close"; }}>
                <option value="open">Open (increase position)</option>
                <option value="close">Close (decrease position)</option>
              </select>
            </div>
            <div class="row field">
              <label>Position step (%)</label>
              <div class="stepper">
                <button @click=${() => { if (this._positionIncrement > 1) this._positionIncrement--; }}>−</button>
                <span>${this._positionIncrement}</span>
                <button @click=${() => { if (this._positionIncrement < 100) this._positionIncrement++; }}>+</button>
              </div>
            </div>
          ` : ""}
        </div>
      ` : ""}

      <!-- Blind Settings -->
      <div class="section">
        <div class="section-title">Blind Settings</div>
        <div class="field">
          <label>Device</label>
          <div class="device-picker" @click=${() => { this._deviceSearchOpen = !this._deviceSearchOpen; }}>
            <span class="${this._deviceId ? "device-name" : "device-none"}">
              ${this._deviceName || this._deviceId || "Select a cover device…"}
            </span>
            <span class="device-chevron">›</span>
          </div>
          ${this._deviceSearchOpen ? html`
            <div class="device-list">
              <input
                class="device-search"
                type="text"
                placeholder="Search devices…"
                .value=${this._deviceSearch}
                @input=${(e: Event) => { this._deviceSearch = (e.target as HTMLInputElement).value; }}
                @click=${(e: Event) => e.stopPropagation()}
              />
              <div class="device-options">
                ${this._filteredDevices.length === 0
                  ? html`<div class="device-option" style="color:var(--secondary-text-color)">No devices found</div>`
                  : this._filteredDevices.map((d) => html`
                    <div
                      class="device-option ${d.entity_id === this._deviceId ? "selected" : ""}"
                      @click=${() => this._selectDevice(d)}
                    >
                      <div>
                        <div>${d.friendly_name}</div>
                        <div class="device-option-sub">${d.entity_id}</div>
                      </div>
                      ${d.entity_id === this._deviceId ? html`<span>✓</span>` : ""}
                    </div>
                  `)
                }
              </div>
            </div>
          ` : ""}
        </div>
        <div class="field">
          <label>Position — ${this._position}% open</label>
          <div class="position-row">
            <span style="font-size:12px;color:var(--secondary-text-color)">Closed</span>
            <input
              type="range"
              min="0"
              max="100"
              .value=${String(this._position)}
              @input=${(e: Event) => { this._position = parseInt((e.target as HTMLInputElement).value); }}
            />
            <span style="font-size:12px;color:var(--secondary-text-color)">Open</span>
          </div>
        </div>
      </div>

      ${this._error ? html`<div class="error">${this._error}</div>` : ""}

      <button class="save-btn" ?disabled=${this._saving} @click=${this._save}>
        ${this._saving ? "Saving…" : isEdit ? "Save Changes" : this._createMultiple ? `Create ${this._multipleCount} Alarms` : "Create Alarm"}
      </button>
    `;
  }
}
