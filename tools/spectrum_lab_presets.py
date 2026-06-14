#!/usr/bin/env python3
"""Preset definitions for the PC Spectrum Lab GUI.

The presets are intentionally kept outside the Tkinter application so they can
be covered by fast console tests without requiring a GUI environment.
"""

from __future__ import annotations

from dataclasses import dataclass

from spectrum_lab_model import SignalComponent, SpectrumModification


@dataclass(frozen=True)
class SpectrumLabPreset:
    """One GUI preset: generated input components and spectrum modifications."""

    name: str
    components: tuple[SignalComponent, ...]
    modifications: tuple[SpectrumModification, ...]
    description: str


PRESETS: tuple[SpectrumLabPreset, ...] = (
    SpectrumLabPreset(
        name="Sine gain 1.0",
        components=(SignalComponent(1000.0, 0.25, 0.0),),
        modifications=(SpectrumModification(1000.0, 600.0, 1.0),),
        description="Single mid-band sine, unity gain reference.",
    ),
    SpectrumLabPreset(
        name="Sine gain 0.5",
        components=(SignalComponent(1000.0, 0.25, 0.0),),
        modifications=(SpectrumModification(1000.0, 600.0, 0.5),),
        description="Single sine with attenuation in the current MID hardware band.",
    ),
    SpectrumLabPreset(
        name="Sine gain 1.8",
        components=(SignalComponent(1000.0, 0.20, 0.0),),
        modifications=(SpectrumModification(1000.0, 600.0, 1.8),),
        description="Recommended high-but-safe gain below the Q2.14 limit.",
    ),
    SpectrumLabPreset(
        name="Sine gain 2.0 limit",
        components=(SignalComponent(1000.0, 0.10, 0.0),),
        modifications=(SpectrumModification(1000.0, 600.0, 2.0),),
        description="Positive Q2.14 limit demonstration.",
    ),
    SpectrumLabPreset(
        name="Gain clipping demo 4.0",
        components=(SignalComponent(1000.0, 0.05, 0.0),),
        modifications=(SpectrumModification(1000.0, 600.0, 4.0),),
        description="Requested gain is outside signed Q2.14 and will clip.",
    ),
    SpectrumLabPreset(
        name="Multitone moderate",
        components=(
            SignalComponent(1000.0, 0.006, 0.0),
            SignalComponent(2700.0, 0.004, 0.3),
            SignalComponent(6200.0, 0.003, 0.0),
        ),
        modifications=(
            SpectrumModification(1000.0, 500.0, 1.2),
            SpectrumModification(6200.0, 900.0, 0.8),
        ),
        description="Small multitone frame with moderate gains.",
    ),
    SpectrumLabPreset(
        name="Multitone near limit",
        components=(
            SignalComponent(1000.0, 0.004, 0.0),
            SignalComponent(2000.0, 0.003, 0.2),
            SignalComponent(4500.0, 0.0025, 0.0),
            SignalComponent(9000.0, 0.002, 0.5),
            SignalComponent(15000.0, 0.0015, 0.0),
        ),
        modifications=(
            SpectrumModification(1000.0, 700.0, 1.8),
            SpectrumModification(4500.0, 1000.0, 1.4),
            SpectrumModification(15000.0, 2000.0, 1.0),
        ),
        description="Multitone case close to the recommended fixed-point range.",
    ),
    SpectrumLabPreset(
        name="Same band warning demo",
        components=(
            SignalComponent(1000.0, 0.006, 0.0),
            SignalComponent(2700.0, 0.004, 0.3),
        ),
        modifications=(
            SpectrumModification(1000.0, 500.0, 1.5),
            SpectrumModification(2700.0, 500.0, 0.5),
        ),
        description="Two GUI bands map to the same current hardware MID band.",
    ),
    SpectrumLabPreset(
        name="Nyquist warning demo",
        components=(SignalComponent(26000.0, 0.10, 0.0),),
        modifications=(SpectrumModification(26000.0, 500.0, 1.0),),
        description="Frequency is above Nyquist for 48 kHz sampling.",
    ),
)

DEFAULT_PRESET_NAME = "Multitone moderate"


def preset_names() -> list[str]:
    """Return preset names in GUI display order."""

    return [preset.name for preset in PRESETS]


def preset_by_name(name: str) -> SpectrumLabPreset:
    """Return one preset by name."""

    for preset in PRESETS:
        if preset.name == name:
            return preset
    raise KeyError(f"unknown Spectrum Lab preset: {name}")


def format_components(components: tuple[SignalComponent, ...]) -> str:
    """Format preset components for the GUI text editor."""

    lines = [
        f"{component.frequency_hz:g}, {component.amplitude:g}, {component.phase_rad:g}"
        for component in components
    ]
    return "\n".join(lines) + "\n"


def format_modifications(modifications: tuple[SpectrumModification, ...]) -> str:
    """Format preset spectrum modifications for the GUI text editor."""

    lines = [
        (
            f"{modification.center_frequency_hz:g}, "
            f"{modification.bandwidth_hz:g}, "
            f"{modification.gain:g}"
        )
        for modification in modifications
    ]
    return "\n".join(lines) + "\n"
