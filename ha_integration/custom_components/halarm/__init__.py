"""HAlarm custom integration — exposes /api/halarm/automations."""
from __future__ import annotations

from homeassistant.core import HomeAssistant
from homeassistant.helpers.typing import ConfigType

from .http import HAlarmAutomationsView

DOMAIN = "halarm"


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    """Register the REST view."""
    hass.http.register_view(HAlarmAutomationsView())
    return True
