import { LitElement, html, css } from "lit";
import { customElement, property } from "lit/decorators.js";

const DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"] as const;
const LABELS: Record<string, string> = {
  mon: "Mon", tue: "Tue", wed: "Wed", thu: "Thu",
  fri: "Fri", sat: "Sat", sun: "Sun",
};

@customElement("weekday-picker")
export class WeekdayPicker extends LitElement {
  @property({ type: Array }) weekdays: string[] = [];

  static styles = css`
    :host { display: block; }
    .row {
      display: flex;
      gap: 6px;
      flex-wrap: wrap;
    }
    button {
      padding: 6px 10px;
      border: none;
      border-radius: 16px;
      cursor: pointer;
      font-size: 13px;
      font-weight: 500;
      background: var(--secondary-background-color, #e0e0e0);
      color: var(--primary-text-color, #212121);
      transition: background 0.15s, color 0.15s;
    }
    button.selected {
      background: var(--primary-color, #03a9f4);
      color: #fff;
    }
  `;

  private _toggle(day: string) {
    const next = this.weekdays.includes(day)
      ? this.weekdays.filter((d) => d !== day)
      : [...this.weekdays, day];
    this.dispatchEvent(new CustomEvent("weekdays-changed", { detail: next, bubbles: true, composed: true }));
  }

  render() {
    return html`
      <div class="row">
        ${DAYS.map(
          (d) => html`
            <button
              class=${this.weekdays.includes(d) ? "selected" : ""}
              @click=${() => this._toggle(d)}
            >${LABELS[d]}</button>
          `
        )}
      </div>
    `;
  }
}
