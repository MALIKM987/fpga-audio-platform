#!/usr/bin/env python3
"""Console tests for Spectrum Lab GUI presets."""

from __future__ import annotations

import sys

from spectrum_lab_hardware_backend import (
    hardware_operating_warnings,
    signal_component_warnings,
)
from spectrum_lab_presets import (
    DEFAULT_PRESET_NAME,
    format_components,
    format_modifications,
    preset_by_name,
    preset_names,
)


ERRORS = 0


def report(name: str, passed: bool) -> None:
    global ERRORS
    if passed:
        print(f"TEST {name} PASS")
    else:
        print(f"TEST {name} FAIL")
        ERRORS += 1


def test_required_presets_exist() -> bool:
    required = {
        "Sine gain 1.0",
        "Sine gain 0.5",
        "Sine gain 1.8",
        "Sine gain 2.0 limit",
        "Gain clipping demo 4.0",
        "Multitone moderate",
        "Multitone near limit",
        "Same band warning demo",
        "Nyquist warning demo",
    }
    names = set(preset_names())
    return required.issubset(names) and DEFAULT_PRESET_NAME in names


def test_gain_clipping_preset_warns() -> bool:
    preset = preset_by_name("Gain clipping demo 4.0")
    warnings = hardware_operating_warnings(preset.modifications)
    joined = "\n".join(warnings)
    return "gain 4" in joined and "Q2.14 positive limit" in joined


def test_nyquist_preset_warns() -> bool:
    preset = preset_by_name("Nyquist warning demo")
    warnings = signal_component_warnings(preset.components)
    warnings.extend(hardware_operating_warnings(preset.modifications))
    joined = "\n".join(warnings)
    return "above Nyquist" in joined and "24000" in joined


def test_same_band_preset_warns() -> bool:
    preset = preset_by_name("Same band warning demo")
    warnings = hardware_operating_warnings(preset.modifications)
    return any("same hardware band collision" in warning for warning in warnings)


def test_formatters_are_editor_friendly() -> bool:
    preset = preset_by_name("Multitone moderate")
    component_text = format_components(preset.components)
    modification_text = format_modifications(preset.modifications)
    return (
        component_text.endswith("\n")
        and modification_text.endswith("\n")
        and "," in component_text
        and "," in modification_text
        and len(component_text.splitlines()) == len(preset.components)
        and len(modification_text.splitlines()) == len(preset.modifications)
    )


def main() -> int:
    print("=== SPECTRUM LAB PRESET TEST ===")
    report("required_presets_exist", test_required_presets_exist())
    report("gain_clipping_preset_warns", test_gain_clipping_preset_warns())
    report("nyquist_preset_warns", test_nyquist_preset_warns())
    report("same_band_preset_warns", test_same_band_preset_warns())
    report("formatters_are_editor_friendly", test_formatters_are_editor_friendly())

    if ERRORS == 0:
        print("STATUS=PASS")
        return 0

    print(f"STATUS=FAIL errors={ERRORS}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
