"""HAlarm custom integration — exposes /api/halarm/automations and sidebar panel."""
from __future__ import annotations

import pathlib

from homeassistant.components.http import StaticPathConfig
from homeassistant.components.panel_custom import async_register_panel
from homeassistant.core import HomeAssistant
from homeassistant.helpers.typing import ConfigType

from .http import HAlarmAutomationsView

DOMAIN = "halarm"

FRONTEND_DIST = pathlib.Path(__file__).parent / "frontend" / "dist"


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    """Register the REST view, static files, and sidebar panel."""
    await hass.http.async_register_static_paths([
        StaticPathConfig("/halarm_static", str(FRONTEND_DIST), cache_headers=False)
    ])
    await async_register_panel(
        hass,
        webcomponent_name="halarm-panel",
        sidebar_title="HAlarm",
        sidebar_icon="mdi:alarm",
        frontend_url_path="halarm",
        require_admin=False,
        js_url="/halarm_static/halarm-panel.js",
        embed_iframe=False,
    )
    hass.http.register_view(HAlarmAutomationsView())
    return True
