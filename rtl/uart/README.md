# `rtl/uart/`

Moduły komunikacji UART.

Najważniejsze pliki:

- `uart_rx.v` - odbiornik 8N1.
- `uart_tx.v` - nadajnik 8N1.
- `uart_frame_packet_rx.v` - parser protokołu ramek UART.
- `uart_frame_packet_tx.v` - formatter odpowiedzi UART.
- `uart_frame_buffer_backend.v` - mailbox widoczny dla mini CPU.
- `uart_frame_mock_backend.v` - prosty backend testowy.
- `uart_cpu_fft_console.v` - legacy konsola impulsowa `A5 01 5A`.

W aktualnej architekturze pełnych ramek UART backend nie uruchamia akceleratora
bezpośrednio. Ustawia request w mailboxie, który obsługuje mini CPU.
