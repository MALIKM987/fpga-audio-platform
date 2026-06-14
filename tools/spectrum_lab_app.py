#!/usr/bin/env python3
"""Tkinter GUI for PC-side Spectrum Lab simulation and FPGA comparison."""

from __future__ import annotations

import csv
from pathlib import Path
import sys

try:
    import tkinter as tk
    from tkinter import filedialog, messagebox, ttk
except ImportError as exc:  # pragma: no cover - depends on local Python build.
    print("tkinter is required to run the GUI application.")
    print(f"Import error: {exc}")
    print("The non-GUI model and tests do not require tkinter.")
    raise SystemExit(1) from exc

from spectrum_lab_model import (
    DEFAULT_FRAME_SIZE,
    DEFAULT_SAMPLE_RATE_HZ,
    INT16_MAX,
    SignalComponent,
    SpectrumModification,
    SpectrumLabResult,
    simulate_spectrum_lab,
)
from spectrum_lab_comparison import (
    FrameComparison,
    build_frame_comparison,
    format_error_metrics,
)
from spectrum_lab_hardware_backend import (
    Gains,
    float_gain_to_q2_14,
    hardware_gains_from_modifications,
    hardware_operating_warnings,
    q2_14_to_float,
    run_frame,
    signal_component_warnings,
)
from spectrum_lab_presets import (
    DEFAULT_PRESET_NAME,
    format_components,
    format_modifications,
    preset_by_name,
    preset_names,
)
from uart_transport import MockFpgaTransport, SerialTransport


class PlotCanvas(tk.Canvas):
    """Small dependency-free line plot widget."""

    def __init__(self, master: tk.Widget, title: str) -> None:
        super().__init__(master, width=420, height=190, bg="white", highlightthickness=1)
        self.title = title
        self.bind("<Configure>", lambda _event: self.redraw([]))

    def redraw(self, values: list[float]) -> None:
        self.delete("all")
        width = max(1, self.winfo_width())
        height = max(1, self.winfo_height())
        pad_left = 34
        pad_right = 8
        pad_top = 40
        pad_bottom = 34
        plot_width = max(1, width - pad_left - pad_right)
        plot_height = max(1, height - pad_top - pad_bottom)
        zero_y = pad_top + plot_height / 2.0

        self.create_text(
            8,
            8,
            text=self.title,
            anchor="nw",
            width=max(1, width - 16),
            fill="#222222",
        )
        self.create_line(pad_left, zero_y, width - pad_right, zero_y, fill="#dddddd")
        self.create_line(pad_left, pad_top, pad_left, height - pad_bottom, fill="#dddddd")
        self.create_text(
            pad_left + plot_width / 2.0,
            height - 16,
            text="X: sample index",
            anchor="center",
            fill="#666666",
        )
        self.create_text(
            12,
            pad_top + plot_height / 2.0,
            text="Y: normalized amplitude",
            anchor="center",
            angle=90,
            fill="#666666",
        )

        if not values:
            self.create_text(width / 2, height / 2, text="no data", fill="#777777")
            return

        max_abs = max(abs(value) for value in values) or 1.0
        points: list[float] = []
        last_index = max(1, len(values) - 1)

        for index, value in enumerate(values):
            x = pad_left + plot_width * index / last_index
            y = zero_y - (value / max_abs) * (plot_height / 2.0)
            points.extend([x, y])

        if len(points) >= 4:
            self.create_line(*points, fill="#0b66c3", width=2)

        self.create_text(
            width - pad_right,
            height - 4,
            text=f"max={max_abs:.3g}",
            anchor="se",
            fill="#666666",
        )


def parse_components(text: str) -> list[SignalComponent]:
    components: list[SignalComponent] = []
    for line_no, raw_line in enumerate(text.splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [part.strip() for part in line.replace(";", ",").split(",")]
        if len(parts) not in (2, 3):
            raise ValueError(f"component line {line_no}: expected freq, amplitude[, phase]")
        frequency_hz = float(parts[0])
        amplitude = float(parts[1])
        phase_rad = float(parts[2]) if len(parts) == 3 else 0.0
        components.append(SignalComponent(frequency_hz, amplitude, phase_rad))
    return components


def parse_modifications(text: str) -> list[SpectrumModification]:
    modifications: list[SpectrumModification] = []
    for line_no, raw_line in enumerate(text.splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = [part.strip() for part in line.replace(";", ",").split(",")]
        if len(parts) != 3:
            raise ValueError(f"modification line {line_no}: expected center, bandwidth, gain")
        modifications.append(
            SpectrumModification(
                center_frequency_hz=float(parts[0]),
                bandwidth_hz=float(parts[1]),
                gain=float(parts[2]),
            )
        )
    return modifications


class SpectrumLabApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("FPGA Audio Platform - PC Spectrum Lab")
        self.geometry("1240x980")
        self.result: SpectrumLabResult | None = None
        self.mock_comparison: FrameComparison | None = None
        self.serial_comparison: FrameComparison | None = None

        self.sample_rate_var = tk.StringVar(value=str(int(DEFAULT_SAMPLE_RATE_HZ)))
        self.frame_size_var = tk.StringVar(value=str(DEFAULT_FRAME_SIZE))
        self.backend_mode_var = tk.StringVar(value="Local simulation")
        self.preset_var = tk.StringVar(value=DEFAULT_PRESET_NAME)
        self.serial_port_var = tk.StringVar(value="COM5")
        self.baud_var = tk.StringVar(value="115200")

        self._build_layout()
        self._load_default_values()
        self._set_status(
            "Ready.\n"
            "Backend: Local simulation.\n"
            "Choose a preset or edit the input tables, then run Generate / Simulate."
        )

    def _build_layout(self) -> None:
        root = ttk.Frame(self, padding=10)
        root.pack(fill="both", expand=True)

        settings = ttk.Frame(root)
        settings.pack(fill="x")

        ttk.Label(settings, text="Sample rate Hz").pack(side="left")
        ttk.Entry(settings, textvariable=self.sample_rate_var, width=10).pack(
            side="left",
            padx=(4, 16),
        )
        ttk.Label(settings, text="Frame size").pack(side="left")
        ttk.Entry(settings, textvariable=self.frame_size_var, width=8).pack(
            side="left",
            padx=(4, 16),
        )
        ttk.Button(settings, text="Generate / Simulate", command=self.simulate).pack(
            side="left",
            padx=4,
        )
        ttk.Button(settings, text="Clear", command=self.clear).pack(side="left", padx=4)
        ttk.Button(settings, text="Export samples", command=self.export_samples).pack(
            side="left",
            padx=4,
        )

        preset_settings = ttk.Frame(root)
        preset_settings.pack(fill="x", pady=(8, 0))
        ttk.Label(preset_settings, text="Preset").pack(side="left")
        ttk.Combobox(
            preset_settings,
            textvariable=self.preset_var,
            width=30,
            state="readonly",
            values=preset_names(),
        ).pack(side="left", padx=(4, 8))
        ttk.Button(
            preset_settings,
            text="Load preset",
            command=lambda: self._load_preset(self.preset_var.get()),
        ).pack(side="left", padx=4)
        ttk.Label(
            preset_settings,
            text=(
                "Hardware mapping: GUI bands collapse to current FPGA "
                "BASS/MID/TREBLE gains."
            ),
        ).pack(side="left", padx=(16, 0))

        backend_settings = ttk.Frame(root)
        backend_settings.pack(fill="x", pady=(8, 0))
        ttk.Label(backend_settings, text="Backend").pack(side="left")
        ttk.Combobox(
            backend_settings,
            textvariable=self.backend_mode_var,
            width=22,
            state="readonly",
            values=[
                "Local simulation",
                "Mock FPGA backend",
                "Serial FPGA backend",
            ],
        ).pack(side="left", padx=(4, 16))
        ttk.Label(backend_settings, text="Port").pack(side="left")
        ttk.Entry(backend_settings, textvariable=self.serial_port_var, width=12).pack(
            side="left",
            padx=(4, 16),
        )
        ttk.Label(backend_settings, text="Baud").pack(side="left")
        ttk.Entry(backend_settings, textvariable=self.baud_var, width=8).pack(
            side="left",
            padx=(4, 0),
        )

        info = ttk.PanedWindow(root, orient="horizontal")
        info.pack(fill="x", pady=(8, 0))

        fixed_info = ttk.LabelFrame(info, text="Fixed-point FPGA limits")
        ttk.Label(
            fixed_info,
            justify="left",
            text=(
                "Gain format: signed Q2.14\n"
                "Representable range: -2.0 .. +1.99994\n"
                "Recommended GUI gain range: 0.25 .. 1.8\n"
                "Gain > 2.0 clips in FPGA to about +1.99994\n"
                "Frame size: 256 samples, Fs: 48000 Hz, Nyquist: 24000 Hz"
            ),
        ).pack(fill="x", padx=6, pady=6)
        info.add(fixed_info, weight=1)

        backend_info = ttk.LabelFrame(info, text="Backend meanings")
        ttk.Label(
            backend_info,
            justify="left",
            text=(
                "Local float simulation: ideal PC-side spectrum modification.\n"
                "Mock FPGA backend: UART protocol loopback, no DSP.\n"
                "Serial FPGA backend: real Tang Nano fixed-point DSP result.\n"
                "Differences versus local float are expected near Q2.14 and "
                "BASS/MID/TREBLE limits."
            ),
        ).pack(fill="x", padx=6, pady=6)
        info.add(backend_info, weight=1)

        editors = ttk.PanedWindow(root, orient="horizontal")
        editors.pack(fill="x", pady=10)

        component_frame = ttk.LabelFrame(
            editors,
            text="Input signal components: frequency_hz, amplitude, phase_rad",
        )
        ttk.Label(
            component_frame,
            justify="left",
            text="Example: 1000, 0.25, 0.  Frequencies above Nyquist warn.",
        ).pack(fill="x", padx=6, pady=(6, 0))
        self.component_text = tk.Text(component_frame, height=7, width=54)
        self.component_text.pack(fill="both", expand=True, padx=6, pady=6)
        editors.add(component_frame, weight=1)

        modification_frame = ttk.LabelFrame(
            editors,
            text="Spectrum modifications: center_hz, bandwidth_hz, gain",
        )
        ttk.Label(
            modification_frame,
            justify="left",
            text=(
                "Example: 1000, 600, 1.5.  FPGA currently sends only one "
                "gain per BASS/MID/TREBLE band."
            ),
        ).pack(fill="x", padx=6, pady=(6, 0))
        self.modification_text = tk.Text(modification_frame, height=7, width=54)
        self.modification_text.pack(fill="both", expand=True, padx=6, pady=6)
        editors.add(modification_frame, weight=1)

        plot_grid = ttk.Frame(root)
        plot_grid.pack(fill="both", expand=True)

        self.input_time_plot = PlotCanvas(
            plot_grid,
            "Input signal - generated time-domain input",
        )
        self.local_output_plot = PlotCanvas(
            plot_grid,
            "Local float simulation - ideal PC-side spectrum modification",
        )
        self.mock_output_plot = PlotCanvas(
            plot_grid,
            "Mock FPGA backend - protocol loopback / no DSP",
        )
        self.serial_output_plot = PlotCanvas(
            plot_grid,
            "Serial FPGA backend - real Tang Nano fixed-point DSP result",
        )
        self.mock_diff_plot = PlotCanvas(
            plot_grid,
            "Mock - local difference - loopback minus ideal float",
        )
        self.serial_diff_plot = PlotCanvas(
            plot_grid,
            "Serial - local difference - real FPGA fixed-point minus ideal float",
        )

        plots = [
            self.input_time_plot,
            self.local_output_plot,
            self.mock_output_plot,
            self.serial_output_plot,
            self.mock_diff_plot,
            self.serial_diff_plot,
        ]
        for index, plot in enumerate(plots):
            row = index // 2
            column = index % 2
            plot.grid(row=row, column=column, sticky="nsew", padx=5, pady=5)

        plot_grid.columnconfigure(0, weight=1)
        plot_grid.columnconfigure(1, weight=1)
        plot_grid.rowconfigure(0, weight=1)
        plot_grid.rowconfigure(1, weight=1)
        plot_grid.rowconfigure(2, weight=1)

        status = ttk.LabelFrame(root, text="Status / log")
        status.pack(fill="x", pady=(10, 0))
        self.status_text = tk.Text(
            status,
            height=10,
            wrap="word",
            state="disabled",
            bg="#f8f8f8",
            relief="flat",
        )
        self.status_text.pack(
            fill="both",
            padx=6,
            pady=6,
        )

    def _load_default_values(self) -> None:
        self._load_preset(DEFAULT_PRESET_NAME)

    def _replace_text(self, widget: tk.Text, text: str) -> None:
        widget.delete("1.0", "end")
        widget.insert("1.0", text)

    def _load_preset(self, name: str) -> None:
        preset = preset_by_name(name)
        self.preset_var.set(preset.name)
        self._replace_text(self.component_text, format_components(preset.components))
        self._replace_text(self.modification_text, format_modifications(preset.modifications))
        self._set_status(
            f"Loaded preset: {preset.name}\n"
            f"Description: {preset.description}\n"
            "Run Generate / Simulate to update plots and backend comparisons."
        )

    def _set_status(self, text: str) -> None:
        self.status_text.configure(state="normal")
        self.status_text.delete("1.0", "end")
        self.status_text.insert("1.0", text)
        self.status_text.configure(state="disabled")

    def _settings(self) -> tuple[float, int]:
        sample_rate = float(self.sample_rate_var.get())
        frame_size = int(self.frame_size_var.get())
        if frame_size <= 0:
            raise ValueError("frame size must be positive")
        if sample_rate <= 0.0:
            raise ValueError("sample rate must be positive")
        return sample_rate, frame_size

    def _gain_to_q2_14(self, gain: float) -> int:
        return float_gain_to_q2_14(gain)

    def _hardware_gains(self, modifications: list[SpectrumModification]) -> Gains:
        sample_rate, frame_size = self._settings()
        return hardware_gains_from_modifications(
            modifications,
            sample_rate_hz=sample_rate,
            frame_size=frame_size,
        )

    def _run_backend_comparison(
        self,
        local_result: SpectrumLabResult,
        transport,
        backend_name: str,
        gains: Gains,
        timeout_s: float = 5.0,
    ) -> FrameComparison:
        hardware_result = run_frame(
            local_result.input_int16.samples,
            gains,
            transport,
            timeout_s=timeout_s,
        )
        return build_frame_comparison(
            local_result,
            hardware_result.samples,
            backend_name,
            note=f"status_history={hardware_result.status_history}",
        )

    def simulate(self) -> None:
        try:
            sample_rate, frame_size = self._settings()
            components = parse_components(self.component_text.get("1.0", "end"))
            modifications = parse_modifications(self.modification_text.get("1.0", "end"))
            local_result = simulate_spectrum_lab(
                components,
                modifications,
                sample_rate_hz=sample_rate,
                frame_size=frame_size,
            )
            backend_mode = self.backend_mode_var.get()
            gains = self._hardware_gains(modifications)

            self.result = local_result
            self.mock_comparison = None
            self.serial_comparison = None
            serial_note = "serial not requested"

            if frame_size == DEFAULT_FRAME_SIZE:
                mock_transport = MockFpgaTransport()
                self.mock_comparison = self._run_backend_comparison(
                    local_result,
                    mock_transport,
                    "Mock FPGA backend",
                    gains,
                )
                mock_transport.close()

                if backend_mode == "Serial FPGA backend":
                    port = self.serial_port_var.get().strip()
                    baud = int(self.baud_var.get())
                    if not port:
                        raise ValueError("serial backend requires a COM/TTY port")

                    transport = None
                    try:
                        transport = SerialTransport(port, baudrate=baud, timeout_s=5.0)
                        self.serial_comparison = self._run_backend_comparison(
                            local_result,
                            transport,
                            f"Serial FPGA backend on {port}",
                            gains,
                        )
                        serial_note = f"serial compared on {port}"
                    except Exception as exc:
                        self.serial_comparison = None
                        serial_note = f"serial unavailable: {exc}"
                    finally:
                        if transport is not None:
                            transport.close()
                elif backend_mode == "Mock FPGA backend":
                    serial_note = "serial not requested"
                else:
                    serial_note = "serial not requested"
            else:
                serial_note = "UART backends require a 256-sample frame"

            backend_note = "local simulation + comparison"
        except Exception as exc:  # pragma: no cover - GUI feedback path.
            messagebox.showerror("Simulation error", str(exc))
            return

        self.input_time_plot.redraw(self.result.input_signal)
        self.local_output_plot.redraw(self.result.output_signal)

        if self.mock_comparison is not None:
            self.mock_output_plot.redraw(self.mock_comparison.backend_signal)
            self.mock_diff_plot.redraw(self.mock_comparison.difference_signal)
        else:
            self.mock_output_plot.redraw([])
            self.mock_diff_plot.redraw([])

        if self.serial_comparison is not None:
            self.serial_output_plot.redraw(self.serial_comparison.backend_signal)
            self.serial_diff_plot.redraw(self.serial_comparison.difference_signal)
        else:
            self.serial_output_plot.redraw([])
            self.serial_diff_plot.redraw([])

        frame_size = len(self.result.input_signal)
        input_max = max(abs(value) for value in self.result.input_signal) if frame_size else 0.0
        output_max = max(abs(value) for value in self.result.output_signal) if frame_size else 0.0
        warnings = []
        warnings.extend(signal_component_warnings(components, sample_rate_hz=sample_rate))
        if self.result.input_int16.clipped:
            warnings.append(
                "input clipping: generated float input exceeded signed int16 range"
            )
        if self.result.output_int16.clipped:
            warnings.append(
                "output clipping: local float output exceeded signed int16 range"
            )
        warnings.extend(
            hardware_operating_warnings(
                modifications,
                sample_rate_hz=sample_rate,
                frame_size=frame_size,
            )
        )

        gain_lines = [
            "FPGA gains sent over UART (signed Q2.14):",
            (
                f"- bass={gains.bass_gain} ({q2_14_to_float(gains.bass_gain):.5f}), "
                f"mid={gains.mid_gain} ({q2_14_to_float(gains.mid_gain):.5f}), "
                f"treble={gains.treble_gain} ({q2_14_to_float(gains.treble_gain):.5f})"
            ),
        ]

        warning_lines = ["Warnings:"]
        if warnings:
            warning_lines.extend(f"- {warning}" for warning in warnings)
        else:
            warning_lines.append("- none")

        comparison_lines = [
            "Summary:",
            f"- samples: {frame_size}",
            f"- input max abs: {input_max:.4f}",
            f"- local float output max abs: {output_max:.4f}",
            f"- selected backend: {self.backend_mode_var.get()}",
            f"- backend status: {backend_note}",
            "",
            *gain_lines,
            "",
            *warning_lines,
            "",
            "Comparison metrics:",
        ]

        if self.mock_comparison is not None:
            comparison_lines.append(
                "- mock_vs_local: "
                + format_error_metrics(self.mock_comparison.metrics)
            )
            comparison_lines.append(
                "  Mock is protocol loopback / no DSP, so nonzero difference is "
                "expected when local float spectral gains change the signal."
            )
        else:
            comparison_lines.append("- mock_vs_local: unavailable")

        if self.serial_comparison is not None:
            comparison_lines.append(
                "- serial_vs_local: "
                + format_error_metrics(self.serial_comparison.metrics)
            )
            comparison_lines.append(
                "  Serial FPGA is fixed-point BASS/MID/TREBLE DSP; differences "
                "from ideal local float are expected near fixed-point and band limits."
            )
        else:
            comparison_lines.append(f"- serial_vs_local: {serial_note}")

        self._set_status("\n".join(comparison_lines))

    def clear(self) -> None:
        self.result = None
        self.mock_comparison = None
        self.serial_comparison = None
        self.component_text.delete("1.0", "end")
        self.modification_text.delete("1.0", "end")
        for plot in [
            self.input_time_plot,
            self.local_output_plot,
            self.mock_output_plot,
            self.serial_output_plot,
            self.mock_diff_plot,
            self.serial_diff_plot,
        ]:
            plot.redraw([])
        self._set_status("Ready. Backend: Local simulation.")

    def export_samples(self) -> None:
        if self.result is None:
            messagebox.showinfo("No data", "Generate a simulation first.")
            return
        path = filedialog.asksaveasfilename(
            title="Export samples",
            defaultextension=".csv",
            filetypes=[("CSV files", "*.csv"), ("All files", "*.*")],
        )
        if not path:
            return

        with Path(path).open("w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle)
            writer.writerow(
                [
                    "index",
                    "input",
                    "input_int16",
                    "local_output",
                    "local_output_int16",
                    "mock_output_int16",
                    "mock_minus_local_int16",
                    "serial_output_int16",
                    "serial_minus_local_int16",
                ]
            )
            for index, (input_value, input_i16, output_value, output_i16) in enumerate(
                zip(
                    self.result.input_signal,
                    self.result.input_int16.samples,
                    self.result.output_signal,
                    self.result.output_int16.samples,
                )
            ):
                mock_value = (
                    self.mock_comparison.backend_samples[index]
                    if self.mock_comparison is not None
                    else ""
                )
                mock_diff = (
                    self.mock_comparison.difference_samples[index]
                    if self.mock_comparison is not None
                    else ""
                )
                serial_value = (
                    self.serial_comparison.backend_samples[index]
                    if self.serial_comparison is not None
                    else ""
                )
                serial_diff = (
                    self.serial_comparison.difference_samples[index]
                    if self.serial_comparison is not None
                    else ""
                )
                writer.writerow(
                    [
                        index,
                        input_value,
                        input_i16,
                        output_value,
                        output_i16,
                        mock_value,
                        mock_diff,
                        serial_value,
                        serial_diff,
                    ]
                )

        self._set_status(
            f"Exported CSV: {path}\nBackend: {self.backend_mode_var.get()}"
        )


def main() -> int:
    app = SpectrumLabApp()
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
