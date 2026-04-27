import { LitElement, html, css, PropertyValues } from "lit";
import { customElement, property, state } from "lit/decorators.js";
import { Alarm, HassObject } from "./types.js";

const ALL_DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];

function weekdayLabel(weekdays: string[]): string {
  const sorted = ALL_DAYS.filter((d) => weekdays.includes(d));
  if (sorted.length === 7) return "Every day";
  const weekdaySet = ["mon", "tue", "wed", "thu", "fri"];
  const weekendSet = ["sat", "sun"];
  if (weekdaySet.every((d) => sorted.includes(d)) && sorted.length === 5) return "Weekdays";
  if (weekendSet.every((d) => sorted.includes(d)) && sorted.length === 2) return "Weekends";
  return sorted.map((d) => d[0].toUpperCase() + d.slice(1)).join(", ");
}

function pad(n: number) {
  return String(n).padStart(2, "0");
}

@customElement("alarm-list")
export class AlarmList extends LitElement {
  @property({ attribute: false }) hass!: HassObject;
  @property({ type: Array }) alarms: Alarm[] = [];
  @property({ type: Boolean }) loading = false;
  @property({ type: String }) error = "";
  @property({ type: Boolean }) shiftOpen = false;

  @state() private _shiftMinutes = 0;
  @state() private _shifting = false;

  private static readonly SHIFT_RANGE = 120;

  static styles = css`
    :host { display: block; padding: 16px; }

    .shift-bar {
      position: fixed;
      left: 0;
      right: 0;
      bottom: 0;
      z-index: 10;
      display: flex;
      flex-direction: column;
      gap: 10px;
      padding: 14px 16px calc(14px + env(safe-area-inset-bottom, 0px));
      background: var(--card-background-color, #fff);
      border-top: 1px solid var(--divider-color, #e0e0e0);
      box-shadow: 0 -4px 16px rgba(0, 0, 0, 0.12);
      box-sizing: border-box;
      animation: shift-slide-up 0.18s ease-out;
    }
    @keyframes shift-slide-up {
      from { transform: translateY(100%); }
      to { transform: translateY(0); }
    }

    /* Reserve space at the bottom of the list so the last row isn't hidden
       behind the fixed shift bar when it's open. */
    .list-padding-for-shift-bar {
      height: 180px;
    }

    .shift-header {
      display: flex;
      align-items: baseline;
      justify-content: space-between;
      gap: 12px;
    }
    .shift-title {
      font-size: 13px;
      font-weight: 600;
      color: var(--secondary-text-color);
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }
    .shift-readout {
      font-size: 20px;
      font-weight: 700;
      font-variant-numeric: tabular-nums;
      color: var(--primary-color, #03a9f4);
      min-width: 60px;
      text-align: right;
    }
    .shift-readout.zero { color: var(--secondary-text-color); }

    .shift-slider-row {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .shift-slider-row input[type=range] {
      flex: 1;
      accent-color: var(--primary-color, #03a9f4);
    }
    .shift-scale {
      font-size: 11px;
      color: var(--secondary-text-color);
      font-variant-numeric: tabular-nums;
      min-width: 28px;
      text-align: center;
    }

    .shift-actions {
      display: flex;
      justify-content: flex-end;
      gap: 8px;
    }
    .shift-actions button {
      padding: 7px 14px;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      font-size: 13px;
      font-weight: 600;
    }
    .shift-apply { background: var(--primary-color, #03a9f4); color: #fff; }
    .shift-apply:disabled { opacity: 0.4; cursor: default; }
    .shift-reset { background: var(--secondary-background-color, #f0f0f0); color: var(--primary-text-color); }
    .shift-cancel { background: none; color: var(--secondary-text-color); }

    .status { text-align: center; padding: 32px; color: var(--secondary-text-color); }
    .error { color: var(--error-color, #f44336); background: var(--error-color-background, #fdecea); padding: 10px 14px; border-radius: 8px; margin-bottom: 12px; font-size: 14px; }

    ul { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 10px; }

    li {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 14px 16px;
      background: var(--card-background-color, #fff);
      border-radius: 12px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.08);
      cursor: pointer;
    }
    li:hover { background: var(--secondary-background-color, #f9f9f9); }

    .alarm-time {
      font-size: 28px;
      font-weight: 700;
      font-variant-numeric: tabular-nums;
      min-width: 72px;
      color: var(--primary-text-color);
    }

    .alarm-time.shifted {
      color: var(--primary-color, #03a9f4);
    }
    .alarm-time-orig {
      display: block;
      font-size: 12px;
      font-weight: 500;
      color: var(--secondary-text-color);
      text-decoration: line-through;
      margin-top: -2px;
    }

    .alarm-info { flex: 1; min-width: 0; }
    .alarm-label { font-size: 15px; font-weight: 600; color: var(--primary-text-color); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .alarm-meta { font-size: 12px; color: var(--secondary-text-color); margin-top: 2px; }

    .alarm-actions { display: flex; align-items: center; gap: 8px; }

    .toggle {
      position: relative;
      width: 44px;
      height: 24px;
      flex-shrink: 0;
    }
    .toggle input { opacity: 0; width: 0; height: 0; }
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
      width: 18px;
      height: 18px;
      left: 3px;
      top: 3px;
      background: #fff;
      border-radius: 50%;
      transition: transform 0.2s;
    }
    .toggle input:checked + .slider { background: var(--primary-color, #03a9f4); }
    .toggle input:checked + .slider:before { transform: translateX(20px); }

    .delete-btn {
      background: none;
      border: none;
      cursor: pointer;
      color: var(--secondary-text-color);
      font-size: 18px;
      padding: 4px;
      border-radius: 6px;
      line-height: 1;
    }
    .delete-btn:hover { color: var(--error-color, #f44336); background: var(--error-color-background, #fdecea); }
  `;

  updated(changed: PropertyValues) {
    // When the parent closes the shift sheet, reset the in-progress slider value.
    if (changed.has("shiftOpen") && !this.shiftOpen) {
      this._shiftMinutes = 0;
    }
  }

  private _onEdit(alarm: Alarm) {
    this.dispatchEvent(new CustomEvent("edit", { detail: alarm, bubbles: true, composed: true }));
  }

  private async _onDelete(e: Event, id: string) {
    e.stopPropagation();
    if (!confirm("Delete this alarm?")) return;
    this.dispatchEvent(new CustomEvent("delete", { detail: id, bubbles: true, composed: true }));
  }

  private _onToggle(e: Event, alarm: Alarm) {
    e.stopPropagation();
    const enabled = (e.target as HTMLInputElement).checked;
    this.dispatchEvent(new CustomEvent("toggle", { detail: { alarm, enabled }, bubbles: true, composed: true }));
  }

  private async _applyShift() {
    if (!this._shiftMinutes) return;
    this._shifting = true;
    this.dispatchEvent(new CustomEvent("shift", { detail: this._shiftMinutes, bubbles: true, composed: true }));
    this._shifting = false;
    this._shiftMinutes = 0;
    this.dispatchEvent(new CustomEvent("shift-close", { bubbles: true, composed: true }));
  }

  private _closeShift() {
    this._shiftMinutes = 0;
    this.dispatchEvent(new CustomEvent("shift-close", { bubbles: true, composed: true }));
  }

  private _computeShiftedTime(alarm: Alarm): { hour: number; minute: number } {
    const total = ((alarm.hour * 60 + alarm.minute + this._shiftMinutes) % 1440 + 1440) % 1440;
    return { hour: Math.floor(total / 60), minute: total % 60 };
  }

  private _formatShiftReadout(mins: number): string {
    if (mins === 0) return "0 min";
    const sign = mins > 0 ? "+" : "−";
    const abs = Math.abs(mins);
    if (abs < 60) return `${sign}${abs} min`;
    const h = Math.floor(abs / 60);
    const m = abs % 60;
    return m === 0 ? `${sign}${h}h` : `${sign}${h}h ${m}m`;
  }

  private _formatShiftEdge(mins: number): string {
    const sign = mins > 0 ? "+" : "−";
    const abs = Math.abs(mins);
    if (abs % 60 === 0) return `${sign}${abs / 60}h`;
    return `${sign}${abs}m`;
  }

  render() {
    const shiftOpen = this.shiftOpen;
    const shift = this._shiftMinutes;
    const range = AlarmList.SHIFT_RANGE;

    return html`
      ${this.error ? html`<div class="error">${this.error}</div>` : ""}

      ${this.loading
        ? html`<div class="status">Loading…</div>`
        : this.alarms.length === 0
        ? html`<div class="status">No alarms. Tap + to create one.</div>`
        : html`
          <ul>
            ${this.alarms.map((alarm) => {
              const shifted = shiftOpen && shift !== 0 ? this._computeShiftedTime(alarm) : null;
              const displayHour = shifted ? shifted.hour : alarm.hour;
              const displayMinute = shifted ? shifted.minute : alarm.minute;
              return html`
                <li @click=${() => this._onEdit(alarm)}>
                  <span class="alarm-time ${shifted ? "shifted" : ""}">
                    ${pad(displayHour)}:${pad(displayMinute)}
                    ${shifted
                      ? html`<span class="alarm-time-orig">${pad(alarm.hour)}:${pad(alarm.minute)}</span>`
                      : ""}
                  </span>
                  <div class="alarm-info">
                    <div class="alarm-label">${alarm.label}</div>
                    <div class="alarm-meta">
                      ${weekdayLabel(alarm.weekdays)} &middot;
                      ${alarm.deviceName || alarm.deviceId} &middot;
                      ${alarm.position}% open
                    </div>
                  </div>
                  <div class="alarm-actions" @click=${(e: Event) => e.stopPropagation()}>
                    <label class="toggle">
                      <input type="checkbox" .checked=${alarm.isEnabled} @change=${(e: Event) => this._onToggle(e, alarm)} />
                      <span class="slider"></span>
                    </label>
                    <button class="delete-btn" title="Delete" @click=${(e: Event) => this._onDelete(e, alarm.id)}>✕</button>
                  </div>
                </li>
              `;
            })}
          </ul>
        `}

      ${shiftOpen ? html`<div class="list-padding-for-shift-bar"></div>` : ""}

      ${shiftOpen ? html`
        <div class="shift-bar">
          <div class="shift-header">
            <span class="shift-title">Shift all alarms</span>
            <span class="shift-readout ${shift === 0 ? "zero" : ""}">
              ${this._formatShiftReadout(shift)}
            </span>
          </div>
          <div class="shift-slider-row">
            <span class="shift-scale">${this._formatShiftEdge(-range)}</span>
            <input
              type="range"
              min="${-range}"
              max="${range}"
              step="1"
              .value=${String(shift)}
              @input=${(e: Event) => { this._shiftMinutes = parseInt((e.target as HTMLInputElement).value) || 0; }}
            />
            <span class="shift-scale">${this._formatShiftEdge(range)}</span>
          </div>
          <div class="shift-actions">
            <button class="shift-cancel" @click=${this._closeShift}>Cancel</button>
            <button class="shift-reset" ?disabled=${shift === 0} @click=${() => { this._shiftMinutes = 0; }}>Reset</button>
            <button class="shift-apply" ?disabled=${shift === 0 || this._shifting} @click=${this._applyShift}>
              ${this._shifting ? "Applying…" : "Apply"}
            </button>
          </div>
        </div>
      ` : ""}
    `;
  }
}
