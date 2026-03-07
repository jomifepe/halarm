"""REST API view exposing halarm automations."""
from __future__ import annotations

import os
import yaml

from homeassistant.components.http import HomeAssistantView


class HAlarmAutomationsView(HomeAssistantView):
    """Return all automations whose alias starts with 'halarm_'."""

    url = "/api/halarm/automations"
    name = "api:halarm:automations"
    requires_auth = True

    async def get(self, request):
        hass = request.app["hass"]
        config_dir = hass.config.config_dir
        automations_path = os.path.join(config_dir, "automations.yaml")

        try:
            with open(automations_path, encoding="utf-8") as f:
                automations = yaml.safe_load(f) or []
        except FileNotFoundError:
            return self.json([])

        if not isinstance(automations, list):
            return self.json([])

        halarm = [
            a for a in automations
            if isinstance(a, dict) and a.get("alias", "").startswith("halarm_")
        ]
        return self.json(halarm)
