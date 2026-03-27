export interface Alarm {
  id: string;
  label: string;
  hour: number;
  minute: number;
  weekdays: string[]; // ["mon","tue",...]
  isEnabled: boolean;
  deviceId: string;
  deviceName: string;
  position: number; // 0–100
}

export interface CoverEntity {
  entity_id: string;
  friendly_name: string;
}

export interface HAState {
  entity_id: string;
  state: string;
  attributes: Record<string, unknown>;
}

export interface HAAutomation {
  id?: string;
  alias: string;
  description: string;
  triggers: unknown[];
  conditions: unknown[];
  actions: unknown[];
  mode: string;
}

export interface HassObject {
  states: Record<string, HAState>;
  callApi<T>(method: string, path: string, data?: unknown): Promise<T>;
  callService(domain: string, service: string, data?: Record<string, unknown>): Promise<void>;
}
