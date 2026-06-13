#!/usr/bin/env python3
"""Tkinter MVP for PC-side Spectrum Lab simulation mode."""

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
    SignalComponent,
    SpectrumModification,
    SpectrumLabResult,
    simulate_spectrum_lab,
)


class PlotCanvas(tk.Canvas):
    """Small dependency-free line plot widget."""

    def __init__(self, master: tk.Widget, title: str) -> None:
        super().__init__(master, width=360, height=180, bg="white", highlightthickness=1)
        self.title = title
        self.bind("<Configure>", lambda _event: self.redraw([]))

    def redraw(self, values: list[float]) -> None:
        self.delete("all")
        width = max(1, self.winfo_width())
        height = max(1, self.winfo_height())
        pad_left = 34
        pad_right = 8
        pad_top = 22
        pad_bottom = 20
        plot_width = max(1, width - pad_left - pad_right)
        plot_height = max(1, height - pad_top - pad_bottom)
        zero_y = pad_top + plot_height / 2.0

        self.create_text(8, 8, text=self.title, anchor="nw", fill="#222222")
        self.create_line(pad_left, zero_y, width - pad_right, zero_y, fill="#dddddd")
        self.create_line(pad_left, pad_top, pad_left, height - pad_bottom, fill="#dddddd")

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
            height - 5,
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
        self.geometry("1040x760")
        self.result: SpectrumLabResult | None = None

        self.sample_rate_var = tk.StringVar(value=str(int(DEFAULT_SAMPLE_RATE_HZ)))
        self.frame_size_var = tk.StringVar(value=str(DEFAULT_FRAME_SIZE))
        self.status_var = tk.StringVar(
            value="UART hardware backend not implemented in this branch."
        )

        self._build_layout()
        self._load_default_values()

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

        editors = ttk.PanedWindow(root, orient="horizontal")
        editors.pack(fill="x", pady=10)

        component_frame = ttk.LabelFrame(
            editors,
            text="Frequency components: frequency_hz, amplitude, phase_rad",
        )
        self.component_text = tk.Text(component_frame, height=7, width=54)
        self.component_text.pack(fill="both", expand=True, padx=6, pady=6)
        editors.add(component_frame, weight=1)

        modification_frame = ttk.LabelFrame(
            editors,
            text="Spectrum modifications: center_hz, bandwidth_hz, gain",
        )
        self.modification_text = tk.Text(modification_frame, height=7, width=54)
        self.modification_text.pack(fill="both", expand=True, padx=6, pady=6)
        editors.add(modification_frame, weight=1)

        plot_grid = ttk.Frame(root)
        plot_grid.pack(fill="both", expand=True)

        self.input_time_plot = PlotCanvas(plot_grid, "Input signal")
        self.input_spectrum_plot = PlotCanvas(plot_grid, "Input spectrum")
        self.output_time_plot = PlotCanvas(plot_grid, "Output signal")
        self.output_spectrum_plot = PlotCanvas(plot_grid, "Output spectrum")

        plots = [
            self.input_time_plot,
            self.input_spectrum_plot,
            self.output_time_plot,
            self.output_spectrum_plot,
        ]
        for index, plot in enumerate(plots):
            row = index // 2
            column = index % 2
            plot.grid(row=row, column=column, sticky="nsew", padx=5, pady=5)

        plot_grid.columnconfigure(0, weight=1)
        plot_grid.columnconfigure(1, weight=1)
        plot_grid.rowconfigure(0, weight=1)
        plot_grid.rowconfigure(1, weight=1)

        status = ttk.LabelFrame(root, text="Status / log")
        status.pack(fill="x", pady=(10, 0))
        ttk.Label(status, textvariable=self.status_var, justify="left").pack(
            fill="x",
            padx=6,
            pady=6,
        )

    def _load_default_values(self) -> None:
        self.component_text.insert(
            "1.0",
            "1000, 0.70, 0\n2700, 0.35, 0.3\n6200, 0.20, 0\n",
        )
        self.modification_text.insert(
            "1.0",
            "1000, 300, 1.8\n2700, 500, 0.5\n",
        )

    def _settings(self) -> tuple[float, int]:
        sample_rate = float(self.sample_rate_var.get())
        frame_size = int(self.frame_size_var.get())
        if frame_size <= 0:
            raise ValueError("frame size must be positive")
        if sample_rate <= 0.0:
            raise ValueError("sample rate must be positive")
        return sample_rate, frame_size

    def simulate(self) -> None:
        try:
            sample_rate, frame_size = self._settings()
            components = parse_components(self.component_text.get("1.0", "end"))
            modifications = parse_modifications(self.modification_text.get("1.0", "end"))
            self.result = simulate_spectrum_lab(
                components,
                modifications,
                sample_rate_hz=sample_rate,
                frame_size=frame_size,
            )
        except Exception as exc:  # pragma: no cover - GUI feedback path.
            messagebox.showerror("Simulation error", str(exc))
            return

        self.input_time_plot.redraw(self.result.input_signal)
        half = max(1, frame_size // 2)
        self.input_spectrum_plot.redraw(self.result.input_magnitude[:half])
        self.output_time_plot.redraw(self.result.output_signal)
        self.output_spectrum_plot.redraw(self.result.output_magnitude[:half])

        input_max = max(abs(value) for value in self.result.input_signal) if frame_size else 0.0
        output_max = max(abs(value) for value in self.result.output_signal) if frame_size else 0.0
        warnings = []
        if self.result.input_int16.clipped:
            warnings.append("input clipping")
        if self.result.output_int16.clipped:
            warnings.append("output clipping")
        warning_text = ", ".join(warnings) if warnings else "no clipping"

        self.status_var.set(
            f"samples={frame_size}; input_max={input_max:.4f}; "
            f"output_max={output_max:.4f}; {warning_text}; "
            "UART hardware backend not implemented in this branch."
        )

    def clear(self) -> None:
        self.result = None
        self.component_text.delete("1.0", "end")
        self.modification_text.delete("1.0", "end")
        for plot in [
            self.input_time_plot,
            self.input_spectrum_plot,
            self.output_time_plot,
            self.output_spectrum_plot,
        ]:
            plot.redraw([])
        self.status_var.set("UART hardware backend not implemented in this branch.")

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
            writer.writerow(["index", "input", "input_int16", "output", "output_int16"])
            for index, (input_value, input_i16, output_value, output_i16) in enumerate(
                zip(
                    self.result.input_signal,
                    self.result.input_int16.samples,
                    self.result.output_signal,
                    self.result.output_int16.samples,
                )
            ):
                writer.writerow([index, input_value, input_i16, output_value, output_i16])

        self.status_var.set(
            f"exported={path}; UART hardware backend not implemented in this branch."
        )


def main() -> int:
    app = SpectrumLabApp()
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
