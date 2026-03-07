"""REST API view exposing halarm automations."""
from __future__ import annotations

import asyncio
import json
import os
import yaml

from homeassistant.components.http import HomeAssistantView


class HAlarmAutomationsView(HomeAssistantView):
    """Return all automations whose description contains halarm metadata."""

    url = "/api/halarm/automations"
    name = "api:halarm:automations"
    requires_auth = True

    async def get(self, request):
        hass = request.app["hass"]
        config_dir = hass.config.config_dir
        automations_path = os.path.join(config_dir, "automations.yaml")

        try:
            automations = await asyncio.to_thread(self._read_automations, automations_path)
        except FileNotFoundError:
            return self.json([])

        if not isinstance(automations, list):
            return self.json([])

        # Filter for automations with halarm metadata in description
        halarm = [
            a for a in automations
            if isinstance(a, dict) and self._is_halarm_automation(a)
        ]
        return self.json(halarm)

    @staticmethod
    def _read_automations(automations_path: str):
        """Read automations from YAML file (blocking operation)."""
        with open(automations_path, encoding="utf-8") as f:
            return yaml.safe_load(f) or []

    @staticmethod
    def _is_halarm_automation(automation: dict) -> bool:
        """Check if automation has halarm metadata in description."""
        description = automation.get("description", "")
        if not description:
            return False
        try:
            # Clean up the description (remove extra whitespace/newlines)
            clean_description = description.replace('\n', '').strip()
            data = json.loads(clean_description)
            # Valid halarm metadata has 'label', 'deviceId', and 'position'
            return isinstance(data, dict) and all(
                key in data for key in ["label", "deviceId", "position"]
            )
        except (json.JSONDecodeError, TypeError, AttributeError):
            return False
