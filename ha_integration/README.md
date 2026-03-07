# HAlarm Custom Integration

## Installation

1. Copy the `custom_components/halarm/` folder to your Home Assistant config directory:
   ```
   /config/custom_components/halarm/
   ```
2. Add to your `configuration.yaml`:
   ```yaml
   halarm:
   ```
3. Restart Home Assistant.

## What it does

Registers a REST endpoint at `/api/halarm/automations` (authenticated with your HA long-lived access token) that returns all automations whose alias starts with `halarm_`.

## Endpoint

`GET /api/halarm/automations`

Returns: JSON array of automation objects matching the halarm format.

## Example response

```json
[
  {
    "id": "8f5c9e2a-1234-5678-abcd-ef1234567890",
    "alias": "halarm_8f5c9e2a-1234-5678-abcd-ef1234567890",
    "description": "{\"label\":\"Morning Blinds\",\"deviceId\":\"cover.bedroom_blind\",\"position\":75}",
    "triggers": [
      {
        "trigger": "time",
        "at": "07:00:00"
      }
    ],
    "conditions": [
      {
        "condition": "time",
        "weekday": ["mon", "tue", "wed", "thu", "fri"]
      }
    ],
    "actions": [
      {
        "action": "cover.set_cover_position",
        "target": {
          "entity_id": "cover.bedroom_blind"
        },
        "data": {
          "position": 75
        }
      }
    ],
    "mode": "single"
  }
]
```
