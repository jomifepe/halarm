import { LitElement, html, css } from "lit";
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

  @state() private _shiftOpen = false;
  @state() private _shiftMinutes = 0;
  @state() private _shifting = false;

  static styles = css`
    :host { display: block; padding: 16px; }

    .header {
      display: flex;
      align-items: center;
      justify-content: flex-end;
      margin-bottom: 16px;
    }

    .header-actions { display: flex; gap: 8px; }

    button.icon-btn {
      background: none;
      border: none;
      cursor: pointer;
      padding: 6px;
      border-radius: 8px;
      color: var(--primary-color, #03a9f4);
      font-size: 13px;
      font-weight: 500;
    }
    button.icon-btn:hover { background: var(--secondary-background-color, #f5f5f5); }

    .add-btn {
      background: var(--primary-color, #03a9f4);
      color: #fff;
      border: none;
      border-radius: 8px;
      padding: 8px 16px;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
    }

    .shift-bar {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 10px 12px;
      background: var(--secondary-background-color, #f5f5f5);
      border-radius: 10px;
      margin-bottom: 14px;
    }
    .shift-bar label { font-size: 13px; color: var(--secondary-text-color); }
    .shift-bar input[type=number] {
      width: 64px;
      padding: 4px 8px;
      border: 1px solid var(--divider-color, #ccc);
      border-radius: 6px;
      background: var(--card-background-color, #fff);
      color: var(--primary-text-color);
      font-size: 14px;
    }
    .shift-bar button {
      padding: 5px 12px;
      border: none;
      border-radius: 6px;
      cursor: pointer;
      font-size: 13px;
      font-weight: 500;
    }
    .shift-apply { background: var(--primary-color, #03a9f4); color: #fff; }
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

  private _onAdd() {
    this.dispatchEvent(new CustomEvent("add", { bubbles: true, composed: true }));
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
    this._shiftOpen = false;
    this._shiftMinutes = 0;
  }

  render() {
    return html`
      <div class="header">
        <div class="header-actions">
          <button class="icon-btn" @click=${() => { this._shiftOpen = !this._shiftOpen; }}>Shift all</button>
          <button class="add-btn" @click=${this._onAdd}>+ Add</button>
        </div>
      </div>

      ${this._shiftOpen ? html`
        <div class="shift-bar">
          <label>Shift all alarms by</label>
          <input
            type="number"
            .value=${String(this._shiftMinutes)}
            @input=${(e: Event) => { this._shiftMinutes = parseInt((e.target as HTMLInputElement).value) || 0; }}
          />
          <label>min (negative = earlier)</label>
          <button class="shift-apply" ?disabled=${this._shifting} @click=${this._applyShift}>Apply</button>
          <button class="shift-cancel" @click=${() => { this._shiftOpen = false; }}>Cancel</button>
        </div>
      ` : ""}

      ${this.error ? html`<div class="error">${this.error}</div>` : ""}

      ${this.loading
        ? html`<div class="status">Loading…</div>`
        : this.alarms.length === 0
        ? html`<div class="status">No alarms. Tap + Add to create one.</div>`
        : html`
          <ul>
            ${this.alarms.map((alarm) => html`
              <li @click=${() => this._onEdit(alarm)}>
                <span class="alarm-time">${pad(alarm.hour)}:${pad(alarm.minute)}</span>
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
            `)}
          </ul>
        `}
    `;
  }
}
